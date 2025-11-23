Shader "Custom/BRDF"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MainColor ("Base Color", Color) = (1,1,1,1)
        [Toggle(TOGGLE_NORMAL)] _NORMALTOGGLE("Use Normal", Float) = 0
        _NormalTex("NormalMap",2D) = "bump" {}
        _NormalPower("Normal Power", Range(0, 2)) = 1
        _ShadowAdjust("shadowAdjust", Range(0, 1)) = 0

        [KeywordEnum(Specular, Metallic)] _SurfaceType("Rendrer Type", Float) = 0
        _SpecularMap("Specular Map", 2D) = "white" {}
        [KeywordEnum(None, Use)] _MAP("Use Combined Map", Float) = 0
        _MaskMap("Occlusion(R), Glossness(G), Metallic(B), ShadowMap(A)", 2D) = "white" {}

        [Toggle(TOGGLE_SM_COMBINE)] _COMBINETOGGLE("Add Metallic on Roughness (Substance)", Float) = 0
        [KeywordEnum(Smoothness Map, Roughness Map)] _RoughType("Map Type(S, R)", Float) = 0
        _SmoothnessMap("Smoothness Map", 2D) = "white" {}
        _Smoothness("Smoothness", Range(0, 1)) = 0
        _MetallicMap("Metallic Map", 2D) = "white" {}
        _MetallicMapIntensity("Metallic Map Intensity", Range(.001, 5)) = 1 
        _Metallic("_Metallic", Range(0, 1)) = 0
        _AOMAP("Ambient Occlusion", 2D)= "white" {}
        _AOIntensity("AO Intensity", Range(0, 1)) = 1

        [Toggle(TOGGLE_EMISSION)] _EMISSIONTOGGLE("Use Emisssion", Float) = 0
        [HDR] _Emission("Emission", Color) = (0, 0, 0, 0)
        _EmissionMap("Emission Map", 2D) = "white" {}

        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("Z Test", Float) = 2
    }
    HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Assets/_Effect/Vectors/ColoredShadow/ColorShadowSample.hlsl" 

        #pragma shader_feature TOGGLE_SM_COMBINE       
        #pragma multi_compile _MAP_NONE _MAP_USE
        #pragma shader_feature TOGGLE_EMISSION
        #pragma shader_feature TOGGLE_NORMAL
        #pragma shader_feature _ROUGHTYPE_SMOOTHNESS_MAP _ROUGHTYPE_ROUGHNESS_MAP
        #pragma multi_compile _SURFACETYPE_SPECULAR _SURFACETYPE_METALLIC
        #ifdef _SURFACETYPE_SPECULAR
            #define _SPECULAR
        #elif defined(_SURFACETYPE_METALLIC)
            #define _METALLIC
        #endif

        TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
        TEXTURE2D(_NormalTex); SAMPLER(sampler_NormalTex);
               
        #ifdef _METALLIC
            #ifdef _MAP_NONE
                TEXTURE2D(_SmoothnessMap); SAMPLER(sampler_SmoothnessMap);   
                TEXTURE2D(_MetallicMap); SAMPLER(sampler_MetallicMap);   
                TEXTURE2D(_AOMAP); SAMPLER(sampler_AOMAP);
            #elif defined(_MAP_USE)
                TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap);
            #endif
        #elif defined(_SPECULAR)
            TEXTURE2D(_SpecularMap); SAMPLER(sampler_SpecularMap);  
            TEXTURE2D(_SmoothnessMap); SAMPLER(sampler_SmoothnessMap);  
            TEXTURE2D(_AOMAP); SAMPLER(sampler_AOMAP);
        #endif
        #if TOGGLE_EMISSION
            TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);
        #endif

        CBUFFER_START(UnityPerMaterial)
                half4 _MainTex_ST;
                half4 _NormalTex_ST;
                half4 _MainColor;
                half _NormalPower;
                half _ShadowAdjust;
                half _Smoothness;
                half _Metallic;
                half _MetallicMapIntensity;
                half4 _Emission;               
                half _AOIntensity;
                half _Cutoff;
        CBUFFER_END
        #define _BaseColor _MainColor
        #define _BumpScale _NormalPower
        #define _EmissionColor _Emission 
        #define _BaseMap_ST _MainTex_ST
        #define _OcclusionMap _AOMAP

    ENDHLSL

    SubShader
    {
        Name "ForwardLit"
        Tags { "RenderType"="Opaque" "Queue" = "Geometry" "RenderPipeline"="UniversalPipeline" "LightMode" = "UniversalForward"}
        LOD 100
        ZTest LEqual
        ZWrite On
        Cull [_Cull]
        //Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // make fog work
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_VERTEX
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHT_CALCULATE_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile _ _CLUSTERED_RENDERING
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"  
            //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"   

            #define _SURFACETYPE_METALLIC
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
#if LIGHTMAP_ON
                float2 uvLightmap   : TEXCOORD1;
#endif
            };

            struct v2f
            {
                float4 vertex                   : SV_POSITION;
                float2 uv                       : TEXCOORD0;
                float3 positionWS               : TEXCOORD1;
                half3 normalWS                  : TEXCOORD2;
                half4 tangentWS                 : TEXCOORD3;
                half4 biTangentWS               : TEXCOORD4;
                half3 viewDirWS                 : TEXCOORD5;
                half4 fogFactorAndVertexLight   : TEXCOORD6;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 7);
                half4 screenPosition            : TEXCOORD8;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            #include "Assets/_Effect/Vectors/ColoredShadow/ColorShadowSample.hlsl"           
            #include "BRDF.hlsl"

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.positionWS = vertexInput.positionWS;
                o.normalWS = normalize(vertexNormalInput.normalWS);
                o.tangentWS.xyz = normalize(TransformObjectToWorldDir(v.tangentOS.xyz));
                float tangentSign = v.tangentOS.w * unity_WorldTransformParams.w;
                o.biTangentWS.xyz = normalize( cross(o.normalWS.xyz, o.tangentWS.xyz) * tangentSign);   

                //o.normalWS = vertexNormalInput.normalWS;
                //o.tangentWS.xyz = vertexNormalInput.tangentWS;
                //o.biTangentWS.xyz = vertexNormalInput.bitangentWS;
                o.viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);

                //Fog
                half3 vertexLight = VertexLighting(vertexInput.positionWS, vertexNormalInput.normalWS);
                half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                o.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

                OUTPUT_LIGHTMAP_UV(v.uv, unity_LightmapST, o.lightmapUV);
                OUTPUT_SH(o.normalWS.xyz, o.vertexSH);
                return o;
            }
            
            float4 DebugCascadeIndex(float3 positionWS)
            {
                int cascadeIndex = ComputeCustomCascadeIndex(positionWS);
                float4 colors[4] = {
                    float4(1, 0, 0, 1), // Red
                    float4(0, 1, 0, 1), // Green
                    float4(0, 0, 1, 1), // Blue
                    float4(1, 1, 0, 1)  // Yellow
                };
                return colors[cascadeIndex];
            }

            // Atlas UV 시각화
            float4 DebugAtlasUV(float3 positionWS)
            {
                float4 shadowCoord = TransformWorldToCustomShadowCoord(positionWS);
                return float4(shadowCoord.xy, shadowCoord.z, 1);
            }

            // Shadow Attenuation 시각화
            float4 DebugShadowAttenuation(float3 positionWS)
            {
                float4 shadowCoord = TransformWorldToCustomShadowCoord(positionWS);
                real shadowAttenuation = SAMPLE_TEXTURE2D_SHADOW(
                    _CustomShadowMapDepth,
                    sampler_CustomShadowMapDepth,
                    shadowCoord.xyz
                );
                return float4(shadowAttenuation.xxx, 1);
            }
            half4 frag (v2f i) : SV_Target
            {                
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float3 light_col = SAMPLE_GI(i.lightmapUV, i.vertexSH, i.normalWS);
                //return half4(light_col , 1);

                //shadowCol = DebugColoredShadow(i.positionWS);
                float4 m0 = _CustomWorldToShadow[0][0]; // 행 0 추출 (HLSL index 방식에 따라 조정)
                //return float4(m0.x, m0.y, m0.w, 1); // 색으로 확인

                float4 sc = DebugAtlasUV(i.positionWS);
 
                half4 color = Compute(i);

                // apply fog
                //color.xyz = MixFog(color.xyz, i.fogFactorAndVertexLight.x);

                //return float4(i.positionWS.xyz, 1);

                float4 shadowCol = SampleColoredShadow(i.positionWS);
                //return shadowCol;
                return color ;
            }
            ENDHLSL
        }
        Pass        //Shadow Caster
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
 
            // -------------------------------------
            // Shader Stages
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Universal Pipeline keywords
            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // -------------------------------------
            // Includes
            #define _BaseMap _MainTex
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

            ENDHLSL
        }

        Pass        //DepthOnly
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            ColorMask R
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0
            #pragma multi_compile_instancing
            #define UNITY_SUPPORT_INSTANCING
            // -------------------------------------
            // Shader Stages
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Includes

            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
            // This pass is used when drawing to a _CameraNormalsTexture texture
            Pass        //DepthNormals
            {
                Name "DepthNormals"
                Tags
                {
                    "LightMode" = "DepthNormals"
                }

                // -------------------------------------
                // Render State Commands
                ZWrite On
                Cull[_Cull]

                HLSLPROGRAM
                #pragma target 2.0
                #pragma multi_compile_instancing
                #define UNITY_SUPPORT_INSTANCING
                // -------------------------------------
                // Shader Stages
                #pragma vertex DepthNormalsVertex
                #pragma fragment DepthNormalsFragment

                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local _NORMALMAP
                #pragma shader_feature_local _PARALLAXMAP
                #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
                #pragma shader_feature_local _ALPHATEST_ON
                #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A


                // -------------------------------------
                // Unity defined keywords
                #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

                // -------------------------------------
                // Universal Pipeline keywords
                #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

                //--------------------------------------
                // GPU Instancing
                #pragma multi_compile_instancing
                #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"


                // -------------------------------------
                // Includes
                #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
                ENDHLSL
            }
            Pass
            {
                // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
                // no LightMode tag are also rendered by Universal Render Pipeline
                Name "GBuffer"
                Tags
                {
                    "LightMode" = "UniversalGBuffer"
                }

                // -------------------------------------
                // Render State Commands
                ZWrite[_ZWrite]
                ZTest LEqual
                Cull[_Cull]

                HLSLPROGRAM
                #pragma target 4.5

                // Deferred Rendering Path does not support the OpenGL-based graphics API:
                // Desktop OpenGL, OpenGL ES 3.0, WebGL 2.0.
                #pragma exclude_renderers gles3 glcore

                // -------------------------------------
                // Shader Stages
                #pragma vertex LitGBufferPassVertex
                #pragma fragment LitGBufferPassFragment

                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local _NORMALMAP
                #pragma shader_feature_local_fragment _ALPHATEST_ON
                //#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
                #pragma shader_feature_local_fragment _EMISSION
                #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
                #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                #pragma shader_feature_local_fragment _OCCLUSIONMAP
                #pragma shader_feature_local _PARALLAXMAP
                #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED

                #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
                #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
                #pragma shader_feature_local_fragment _SPECULAR_SETUP
                #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
                //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
                //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
                #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
                #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
                #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
                #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
                #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED
                #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
                #include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
                #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

                // -------------------------------------
                // Unity defined keywords
                #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
                #pragma multi_compile _ SHADOWS_SHADOWMASK
                #pragma multi_compile _ DIRLIGHTMAP_COMBINED
                #pragma multi_compile _ LIGHTMAP_ON
                #pragma multi_compile_fragment _ LIGHTMAP_BICUBIC_SAMPLING
                #pragma multi_compile _ DYNAMICLIGHTMAP_ON
                #pragma multi_compile _ USE_LEGACY_LIGHTMAPS
                #pragma multi_compile _ LOD_FADE_CROSSFADE
                #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
                #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ProbeVolumeVariants.hlsl"

                //--------------------------------------
                // GPU Instancing
                #pragma multi_compile_instancing
                #pragma instancing_options renderinglayer
                #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

                // -------------------------------------
                // Includes
                //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitGBufferPass.hlsl"
                #include "GBuffer.hlsl"
                ENDHLSL
            }
            // This pass it not used during regular rendering, only for lightmap baking.
            Pass        //Meta 
            {
                Name "Meta"
                Tags
                {
                    "LightMode" = "Meta"
                }

                // -------------------------------------
                // Render State Commands
                Cull Off

                HLSLPROGRAM
                #pragma target 2.0
                #pragma multi_compile_instancing

                // -------------------------------------
                // Shader Stages
                #pragma vertex UniversalVertexMeta
                #pragma fragment UniversalFragmentMetaLit
                #define UNITY_SUPPORT_INSTANCING
                // -------------------------------------
                // Material Keywords

                #pragma shader_feature_local_fragment _SPECULAR_SETUP
                #pragma shader_feature_local_fragment _EMISSION
                #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
                #pragma shader_feature_local_fragment _ALPHATEST_ON
                #pragma shader_feature_local_fragment _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
                #pragma shader_feature_local_fragment _SPECGLOSSMAP
                #pragma shader_feature EDITOR_VISUALIZATION
                #include "LitInput.hlsl"
                //--------------------------------------
                // GPU Instancing
                #pragma instancing_options renderinglayer
                #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

                // -------------------------------------
                // Includes
                #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"
                ENDHLSL
            }
    }
}










