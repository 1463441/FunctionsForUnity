using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RendererUtils;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using static CameraUtility.AABB2OBB;
using static CustomPostProcessingFeature.Pass;

public class GBufferRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Setting
    {
        public RenderPassEvent renderPassEvent;
    }

    [SerializeField] private Setting setting;
    private GBufferRenderPass pass;

    public override void Create()
    {
        pass = new GBufferRenderPass(setting);
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var renderingMode = renderingData.cameraData.camera.actualRenderingPath;

        if (renderingMode == RenderingPath.DeferredShading)
            return;

        if (renderingData.cameraData.isSceneViewCamera)
            return;

        renderer.EnqueuePass(pass);
    }

    public class GBufferRenderPass : ScriptableRenderPass
    {
        private Setting setting;
        private ShaderTagId shaderTagsList;

        private static readonly int _GBuffer0ID = Shader.PropertyToID("_UnityFBInput0");
        private static readonly int _GBuffer1ID = Shader.PropertyToID("_UnityFBInput1");
        private static readonly int _GBuffer2ID = Shader.PropertyToID("_UnityFBInput2");
        public GBufferRenderPass(Setting setting)
        {
            this.renderPassEvent = RenderPassEvent.BeforeRenderingGbuffer;
            this.renderPassEvent = setting.renderPassEvent;
            this.setting = setting;

            shaderTagsList = new ShaderTagId("ForwardGBuffer");
        }

        public class PassData
        {
            public TextureHandle _GBuffer0;
            public TextureHandle _GBuffer1;
            public TextureHandle _GBuffer2;
            public TextureHandle mainLight;
            public RendererListHandle _RendererList;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
            var cameraData = frameData.Get<UniversalCameraData>();
            var renderingData = frameData.Get<UniversalRenderingData>();
            var resource = frameData.Get<UniversalResourceData>();


            TextureDesc textureDesc = new TextureDesc(2560, 1440)
            {
                colorFormat = GraphicsFormat.R8G8B8A8_SRGB,
                depthBufferBits = DepthBits.Depth16,
                clearBuffer = true,
                clearColor = Color.clear,
                filterMode = FilterMode.Bilinear,
                wrapMode = TextureWrapMode.Clamp,
                useMipMap = false,
                autoGenerateMips = false,
            };

            textureDesc.colorFormat = GraphicsFormat.R8G8B8A8_SRGB;
            textureDesc.name = "_GBuffer0";
            TextureHandle _GBuffer0 = renderGraph.CreateTexture(textureDesc);

            textureDesc.colorFormat = GraphicsFormat.R8G8B8A8_UNorm;
            textureDesc.name = "_GBuffer1";
            TextureHandle _GBuffer1 = renderGraph.CreateTexture(textureDesc);

            //textureDesc.colorFormat = GraphicsFormat.R8G8B8A8_UNorm;
            textureDesc.name = "_GBuffer2";
            textureDesc.clearBuffer = false;
            TextureHandle _GBuffer2 = renderGraph.CreateTexture(textureDesc);

            textureDesc.colorFormat = GraphicsFormat.D16_UNorm;
            textureDesc.name = "Depth";
            TextureHandle textureHandle = renderGraph.CreateTexture(textureDesc);

            var mainLight = resource.mainShadowsTexture;

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Forward GBuffer", out var passData))
            {

                passData._GBuffer0 = _GBuffer0;
                passData._GBuffer1 = _GBuffer1;
                passData._GBuffer2 = _GBuffer2;
                passData.mainLight = mainLight;

                builder.UseTexture(passData.mainLight, AccessFlags.Read);
                builder.SetRenderAttachment(passData._GBuffer0, 0, AccessFlags.Write);
                builder.SetRenderAttachment(passData._GBuffer1, 1, AccessFlags.Write);
                builder.SetRenderAttachment(passData._GBuffer2, 2, AccessFlags.Write);
                builder.SetRenderAttachmentDepth(textureHandle, AccessFlags.Write);

                var listDesc = new RendererListDesc(shaderTagsList, renderingData.cullResults, cameraData.camera)
                {
                    sortingCriteria = SortingCriteria.CommonOpaque,
                    layerMask = -1,
                    renderQueueRange = RenderQueueRange.opaque,
                    rendererConfiguration = PerObjectData.None,
                    excludeObjectMotionVectors = false,
                };
                var renderList = renderGraph.CreateRendererList(listDesc);
                passData._RendererList = renderList;
                builder.UseRendererList(passData._RendererList);

                builder.AllowGlobalStateModification(true);

                builder.SetGlobalTextureAfterPass(passData._GBuffer0, _GBuffer0ID);
                builder.SetGlobalTextureAfterPass(passData._GBuffer1, _GBuffer1ID);
                builder.SetGlobalTextureAfterPass(passData._GBuffer2, _GBuffer2ID);

                builder.SetRenderFunc((PassData pass, RasterGraphContext ctx) => 
                {
                    ctx.cmd.DrawRendererList(pass._RendererList);
                });
            }
        }
    }
}
