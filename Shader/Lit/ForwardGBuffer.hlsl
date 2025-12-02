#pragma once

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"  
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GBufferCommon.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
//    output.gBuffer0 = half4(surfaceData.albedo.rgb, PackGBufferMaterialFlags(materialFlags));   // albedo          albedo          albedo          materialFlags   (sRGB rendertarget)
//    output.gBuffer1 = half4(surfaceData.specular.rgb, surfaceData.occlusion);                   // specular        specular        specular        occlusion
//    output.gBuffer2 = half4(packedNormalWS, surfaceData.smoothness);                            // encoded-normal  encoded-normal  encoded-normal  smoothness
//    output.color    = half4(globalIllumination, 1);                                             // GI              GI              GI              unused          (lighting buffer)

struct GBufferFragOutput
{
    half4 gBuffer0 : SV_Target0; //diffuse.xyz, materialFlags
    half4 gBuffer1 : SV_Target1; //metallic.x or specular.xyz, occlusion
    half4 gBuffer2 : SV_Target2; //encoded-normal.xyz, smoothness
};

#undef DECL_SV_TARGET
#undef DECL_OPT_GBUFFER_TARGET

struct appdata
{
    float4 vertex : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    half3 normalWS : TEXCOORD2;
    half4 tangentWS : TEXCOORD3;
    #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
        half3 viewDirTS : TEXCOORD6;
    #endif

    #ifdef USE_APV_PROBE_OCCLUSION
        float4 probeOcclusion           : TEXCOORD9;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

#define kMaterialFlagReceiveShadowsOff        1 // Does not receive dynamic shadows
#define kMaterialFlagSpecularHighlightsOff    2 // Does not receive specular
#define kMaterialFlagSubtractiveMixedLighting 4 // The geometry uses subtractive mixed lighting
#define kMaterialFlagSpecularSetup            8 // Lit material use specular setup instead of metallic setup

#ifdef TOGGLE_NORMAL
    #define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif

v2f LitGBufferPassVertex(appdata v)
{
    v2f o;
    VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
    VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(v.normalOS, v.tangentOS);
    o.positionCS = vertexInput.positionCS;
    o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
    o.positionWS = vertexInput.positionWS;
    o.normalWS = normalize(vertexNormalInput.normalWS);
    #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
        real sign = v.tangentOS.w * GetOddNegativeScale();
        o.tangentWS.w = sign;       
    #endif
    o.tangentWS.xyz = normalize(TransformObjectToWorldDir(v.tangentOS.xyz));
    
    float tangentSign = v.tangentOS.w * unity_WorldTransformParams.w;
    o.tangentWS.xyz = vertexNormalInput.tangentWS;

  
    #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
        half3 viewDirTS = GetViewDirectionTangentSpace(o.tangentWS, o.normalWS, o.viewDirWS);
        o.viewDirTS = viewDirTS;
    #endif
    
    return o;
}

    inline void SurfaceDataOptimized(float2 uv, out SurfaceData outSurfaceData)
    {
        outSurfaceData = (SurfaceData) 0;
        half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
        outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);

        half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
        outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
        outSurfaceData.albedo = AlphaModulate(outSurfaceData.albedo, outSurfaceData.alpha);

#if _SPECULAR_SETUP
    outSurfaceData.metallic = half(1.0);
    outSurfaceData.specular = specGloss.rgb;
#else
        outSurfaceData.metallic = specGloss.r;
        outSurfaceData.specular = half3(0.0, 0.0, 0.0);
#endif

        outSurfaceData.smoothness = specGloss.a;
        outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
        outSurfaceData.occlusion = SampleOcclusion(uv);
        outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
    }
 
GBufferFragOutput LitGBufferPassFragment(v2f i)
{
    SurfaceData s;
    SurfaceDataOptimized(i.uv, s);
     
    float3 normalWS;
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(i.positionWS);
#if defined(_NORMALMAP) || defined(_DETAIL)
    float sgn = i.tangentWS.w;
    float3 bitangent = sgn * cross(i.normalWS.xyz, i.tangentWS.xyz);
    normalWS = TransformTangentToWorld(normalTS, half3x3(i.tangentWS.xyz, bitangent.xyz, i.normalWS.xyz));
#else
    normalWS = i.normalWS;
#endif        
    half3 packedNormalWS = PackGBufferNormal((normalWS));
        
        
#ifdef _SPECULAR_SETUP
    half reflectivity = ReflectivitySpecular(s.specular);
    half oneMinusReflectivity = half(1.0) - reflectivity;
    half3 brdfDiffuse = s.albedo * oneMinusReflectivity;
    half3 brdfSpecular = s.specular;
#else
    half oneMinusReflectivity = OneMinusReflectivityMetallic(s.metallic);
    half reflectivity = half(1.0) - oneMinusReflectivity;
    half3 brdfDiffuse = s.albedo * oneMinusReflectivity;
    half3 brdfSpecular = lerp(kDielectricSpec.rgb, s.albedo, s.metallic);
#endif
        
         
    uint materialFlags = 0;

    #ifdef _RECEIVE_SHADOWS_OFF
        materialFlags |= kMaterialFlagReceiveShadowsOff;
    #endif

    half3 packedSpecular;
    half smoothness;
    #ifdef _SURFACETYPE_SPECULAR
        materialFlags |= kMaterialFlagSpecularSetup;
        packedSpecular = brdfSpecular.rgb;
    #else
        packedSpecular.r = reflectivity;
        packedSpecular.gb = 0.0;
    #endif

    #ifdef _SPECULARHIGHLIGHTS_OFF
        materialFlags |= kMaterialFlagSpecularHighlightsOff;
        packedSpecular = 0.0.xxx;
    #endif
   
    GBufferFragOutput output;
    output.gBuffer0 = half4(s.albedo, PackGBufferMaterialFlags(materialFlags));     //albedo 통과
    output.gBuffer1 = half4(packedSpecular, s.occlusion); //통과
    output.gBuffer2 = half4(packedNormalWS, s.smoothness);              //
    
    #if defined(GBUFFER_FEATURE_DEPTH)
        output.depth = i.positionCS.z;
    #endif
        
    return output;
}