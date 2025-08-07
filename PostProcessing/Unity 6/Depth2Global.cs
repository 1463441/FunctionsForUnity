using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RendererUtils;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using static BlitProfile_Feature.BlitPass;
using static UnityEngine.XR.XRDisplaySubsystem;

public class Depth2Global : ScriptableRendererFeature           //1219  CameraDepthTexture 2번 Render 되는 문제만 : 엔진 문제
{

    public class Depth2GlobalPass : ScriptableRenderPass
    {
        private static int s_CameraDepthTexture;
        private static int s_CameraDepthNormalTexture;

        private static string depthTextureName;
        private static string depthNormalTextureName;

        private ProfilingSampler m_ProfilingSampler;
        private ShaderTagId[] shaderTagIds;

        private readonly LayerMask m_LayerMask;
        private readonly RenderQueueRange m_RenderQueueRange;
        private readonly bool m_GenerateDepthNormal;
        private readonly bool m_GenerateDepth;
        private readonly FilteringSettings m_FilteringSettings;
        private readonly RenderStateBlock m_RenderStateBlock;

        //private Material _material;
        public Depth2GlobalPass(RenderPassEvent renderPassEvent, DepthSetting setting)
        {
            this.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;

            s_CameraDepthNormalTexture = Shader.PropertyToID(setting.depthNormalName);
            s_CameraDepthTexture = Shader.PropertyToID(setting.depthName);
            depthTextureName = setting.depthName;
            depthNormalTextureName = setting.depthNormalName;
            //m_ProfilingSampler = new ProfilingSampler(tag);
            m_LayerMask = setting.layer;
            m_RenderQueueRange = setting.queueRange == default ? RenderQueueRange.all : setting.queueRange;
            m_GenerateDepthNormal = setting.DepthNormal;
            m_GenerateDepth = setting.Depth;
            m_FilteringSettings = new FilteringSettings(setting.queueRange, setting.layer);
            m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);

            /*shaderTagIds.Add(new ShaderTagId("SRPDefaultUnlit"));
            shaderTagIds.Add(new ShaderTagId("UniversalForward"));  
            shaderTagIds.Add(new ShaderTagId("UniversalForwardOnly"));
            shaderTagIds.Add(new ShaderTagId("Universal2D"));   //2D   */

            List<ShaderTagId> shaderTags = new List<ShaderTagId>();
            if (m_GenerateDepth && m_GenerateDepthNormal)
            {
                shaderTags.Add(new ShaderTagId("DepthNormals"));
            }
            else if (m_GenerateDepth)
            {
                shaderTags.Add(new ShaderTagId("DepthOnly"));
            }
            else if (m_GenerateDepthNormal)
            {
                shaderTags.Add(new ShaderTagId("DepthNormals"));
                shaderTags.Add(new ShaderTagId("DepthNormalsOnly"));
            }

            shaderTagIds = shaderTags.ToArray();
            shaderTags.Clear();
            shaderTags = null;
        }
        private class OnePassData  //DepthOnly or NormalOnly
        {
            internal Camera camera;
            internal RendererListHandle rendererListHandle;
        }
        private class PassData
        {
            internal Camera camera;
            internal RendererListHandle rendererListHandle;
            internal TextureHandle normalTexture;
            internal TextureHandle depthBuffer;
            internal TextureHandle depthTexture;
        }

        void CreateRendererList(RenderGraph renderGraph, UniversalRenderingData renderingData, UniversalCameraData cameraData, ShaderTagId[] shaderTags, out RendererListHandle handle)
        {
            RendererListDesc rendererListDesc = new RendererListDesc(shaderTags, renderingData.cullResults, cameraData.camera)
            {
                layerMask = m_LayerMask,
                renderQueueRange = m_RenderQueueRange,
                sortingCriteria = m_RenderQueueRange.lowerBound >= (int)RenderQueue.Transparent
                    ? SortingCriteria.CommonTransparent
                : cameraData.defaultOpaqueSortFlags,//SortingCriteria.CommonOpaque,
                overrideShader = null,
                overrideShaderPassIndex = 0,
                rendererConfiguration = PerObjectData.None, // Minimize data transfer for performance
                // PerObjectData.LightData | PerObjectData.ReflectionProbes | PerObjectData.LightProbe;
                renderingLayerMask = uint.MaxValue,
                stateBlock = new RenderStateBlock(RenderStateMask.Nothing),
                excludeObjectMotionVectors = false
            };

            handle = renderGraph.CreateRendererList(rendererListDesc);
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var cameraData = frameData.Get<UniversalCameraData>();
            var renderingData = frameData.Get<UniversalRenderingData>();

            var camera = cameraData.camera;
            int scaledWidth = Mathf.Max(1, (int)(camera.pixelWidth * cameraData.renderScale));
            int scaledHeight = Mathf.Max(1, (int)(camera.pixelHeight * cameraData.renderScale));

            if (m_GenerateDepth && m_GenerateDepthNormal)
            {
                // 둘 다 필요한 경우: DepthNormal 렌더링 후 Depth만 복사
                CameraDepthNormals(renderGraph, cameraData, renderingData, scaledWidth, scaledHeight);
            }
            else if (m_GenerateDepthNormal)
            {
                // DepthNormal만 필요한 경우
                CameraNormalsOnly(renderGraph, cameraData, renderingData, scaledWidth, scaledHeight);
            }
            else if (m_GenerateDepth)
            {
                // Depth만 필요한 경우
                CameraDepthOnly(renderGraph, cameraData, renderingData, scaledWidth, scaledHeight);
            }
        }

        private void CameraDepthNormals(RenderGraph renderGraph, UniversalCameraData cameraData,
                                               UniversalRenderingData renderingData, int scaledWidth, int scaledHeight)
        {
            using (var builder = renderGraph.AddRasterRenderPass<PassData>("DepthNormal with Depth", out var data))
            {
                data.camera = cameraData.camera;

                // DepthNormal 텍스처 생성
                var depthNormalDesc = new TextureDesc(scaledWidth, scaledHeight)
                {
                    name = depthNormalTextureName,
                    colorFormat = GraphicsFormat.R8G8B8A8_SNorm,
                    depthBufferBits = DepthBits.None,
                    clearBuffer = true,
                    clearColor = Color.clear
                };

                // 실제 깊이 버퍼 (이것을 나중에 복사할 것)
                var depthBufferDesc = new TextureDesc(scaledWidth, scaledHeight)
                {
                    name = "MainDepthBuffer",
                    colorFormat = GraphicsFormat.None,
                    depthBufferBits = DepthBits.Depth32,
                    clearBuffer = true,
                    clearColor = Color.clear
                };

                // 최종 Depth 텍스처 (복사용)
                var finalDepthDesc = new TextureDesc(scaledWidth, scaledHeight)
                {
                    name = depthTextureName,
                    colorFormat = GraphicsFormat.R32_SFloat, // Depth 전용 포맷
                    depthBufferBits = DepthBits.None,
                    clearBuffer = true,
                    clearColor = Color.clear
                };

                data.normalTexture = renderGraph.CreateTexture(depthNormalDesc);
                data.depthBuffer = renderGraph.CreateTexture(depthBufferDesc);
                data.depthTexture = renderGraph.CreateTexture(finalDepthDesc);

                // DepthNormal 렌더링 설정
                builder.SetRenderAttachment(data.normalTexture, 0);
                builder.SetRenderAttachment(data.depthTexture, 1);
                builder.SetRenderAttachmentDepth(data.depthBuffer);

                // DepthNormal 렌더러 리스트 생성 (DepthNormals 태그만 사용)
                CreateRendererList(renderGraph, renderingData, cameraData,
                                  shaderTagIds, out data.rendererListHandle);
                builder.UseRendererList(data.rendererListHandle);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    context.cmd.SetViewProjectionMatrices(data.camera.worldToCameraMatrix, data.camera.projectionMatrix);

                    // DepthNormal 렌더링 (이 과정에서 depth buffer도 함께 생성됨)
                    if (data.rendererListHandle.IsValid())
                        context.cmd.DrawRendererList(data.rendererListHandle);
                });

                // Global 텍스처 설정
                builder.SetGlobalTextureAfterPass(data.normalTexture, s_CameraDepthNormalTexture);
                builder.SetGlobalTextureAfterPass(data.depthBuffer, s_CameraDepthTexture);
            }
            
            /*
            // Depth 복사 패스 (CopyDepth와 유사)
            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Copy Depth", out var copyData))
            {
                var depthBuffer = data.depthBuffer; // 이전 패스의 depth buffer 참조
                var finalDepthTexture = data.finalDepthTexture;

                copyData.sourceDepth = depthBuffer;
                copyData.targetDepth = finalDepthTexture;

                builder.UseTexture(depthBuffer, AccessFlags.Read);
                builder.SetRenderAttachment(finalDepthTexture, 0);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    // Fullscreen quad로 depth 복사 (Unity의 CopyDepth와 동일한 방식)
                    context.cmd.SetGlobalTexture("_SourceDepthTexture", data.sourceDepth);
                    context.cmd.DrawProcedural(Matrix4x4.identity, GetCopyDepthMaterial(), 0,
                                             MeshTopology.Triangles, 3, 1);
                });

                builder.SetGlobalTextureAfterPass(finalDepthTexture, s_CameraDepthTexture);
            }
            */
        }

        private void CameraNormalsOnly(RenderGraph renderGraph, UniversalCameraData cameraData, UniversalRenderingData renderingData,
                                          int scaledWidth, int scaledHeight)
        {
            using (var builder = renderGraph.AddRasterRenderPass<OnePassData>("DepthNormal Pass", out var data))
            {
                data.camera = cameraData.camera;

                var depthNormalDesc = new TextureDesc(scaledWidth, scaledHeight)
                {
                    name = depthNormalTextureName,
                    colorFormat = GraphicsFormat.R8G8B8A8_SNorm,
                    depthBufferBits = DepthBits.None,
                    msaaSamples = MSAASamples.None,
                    clearBuffer = true,
                    clearColor = Color.clear
                };

                // DepthNormal 렌더링을 위한 깊이 버퍼
                var depthBuffer = builder.CreateTransientTexture(new TextureDesc(scaledWidth, scaledHeight)
                {
                    depthBufferBits = DepthBits.Depth32,
                    name = "DepthNormalDepthBuffer"
                });

                CreateRendererList(renderGraph, renderingData, cameraData, shaderTagIds, out data.rendererListHandle);

                builder.UseRendererList(data.rendererListHandle);

                var depthNormalTexture = renderGraph.CreateTexture(depthNormalDesc);
                builder.SetRenderAttachment(depthNormalTexture, 0);
                builder.SetRenderAttachmentDepth(depthBuffer);


                builder.AllowPassCulling(false);

                builder.SetRenderFunc((OnePassData data, RasterGraphContext context) =>
                {
                    context.cmd.SetViewProjectionMatrices(data.camera.worldToCameraMatrix, data.camera.projectionMatrix);

                    if (data.rendererListHandle.IsValid())
                        context.cmd.DrawRendererList(data.rendererListHandle);
                });

                builder.SetGlobalTextureAfterPass(depthNormalTexture, s_CameraDepthNormalTexture);
            }
        }
        private void CameraDepthOnly(RenderGraph renderGraph, UniversalCameraData cameraData, UniversalRenderingData renderingData,
                            int scaledWidth, int scaledHeight)
        {
            using (var builder = renderGraph.AddRasterRenderPass<OnePassData>("Depth Pass", out var data))
            {
                data.camera = cameraData.camera;

                var depthDesc = new TextureDesc(scaledWidth, scaledHeight)
                {
                    name = depthTextureName,
                    colorFormat = GraphicsFormat.None,
                    depthBufferBits = DepthBits.Depth32,
                    clearBuffer = true,
                    clearColor = Color.clear
                };

                CreateRendererList(renderGraph, renderingData, cameraData, shaderTagIds, out data.rendererListHandle);
                builder.UseRendererList(data.rendererListHandle);

                var depthTexture = renderGraph.CreateTexture(depthDesc);
                builder.SetRenderAttachmentDepth(depthTexture);


                builder.SetRenderFunc((OnePassData data, RasterGraphContext context) =>
                {
                    context.cmd.SetViewProjectionMatrices(data.camera.worldToCameraMatrix, data.camera.projectionMatrix);

                    if (data.rendererListHandle.IsValid())
                        context.cmd.DrawRendererList(data.rendererListHandle);
                });

                builder.SetGlobalTextureAfterPass(depthTexture, s_CameraDepthTexture);
            }
        }
        public void Dispose()
        {
            m_ProfilingSampler = null;
            shaderTagIds = null;
            shaderTagIds = null;
        }
    }


    [System.Serializable]
    public class DepthSetting
    {
        [Header("Setting")]
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingPrePasses;
        public RenderQueueRange queueRange = RenderQueueRange.all;
        public bool useLayerSetting = false;
        public LayerMask layer;

        [Header("dEPTH")]
        public bool Depth = false;
        public string depthName = "_DepthTexture";

        [Header("Normal")]
        public bool DepthNormal = false;
        public string depthNormalName = "_CustomNormalTexture";

        [Header("Performance Settings")]
        [Range(0.1f, 1.0f)]
        public float renderScale = 1.0f;

        [Header("Culling Optimization")]
        public bool enableFrustumCulling = true;
        public bool enableOcclusionCulling = false; // Disable by default for better performance
    }


    public Depth2GlobalPass pass;
    public DepthSetting setting;
    private bool m_IsInitialized = false;


    public override void Create()
    {
        if (!setting.Depth && !setting.DepthNormal)
        {
            return;
        }

        pass = new Depth2GlobalPass(setting.passEvent, setting);
        m_IsInitialized = true;
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (!m_IsInitialized || pass == null)
            return;

        if (renderingData.cameraData.isSceneViewCamera || renderingData.cameraData.isPreviewCamera || renderingData.cameraData.cameraType == CameraType.Reflection)
            return;

        pass.ConfigureInput(ScriptableRenderPassInput.Normal | ScriptableRenderPassInput.Depth);
        renderer.EnqueuePass(pass);
    }

    public void UpdateSettings(DepthSetting newSettings)
    {
        if (newSettings == null)
            return;

        setting = newSettings;

        // Recreate render pass with new settings
        if (m_IsInitialized)
        {
            Create();
        }
    }


    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            pass?.Dispose();
            pass = null;
            m_IsInitialized = false;
        }
    }
}