Shader "Unlit/OnlyOutline"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _OutlineColor("Outline Color", Color) = (0,0,0,0)
        _OutlineScale("OutlineScale", Float) = 1
        _DepthThreshold("DepthThreshold", Float) = 0
        _DepthNormalThreshold("DepthNormalThreshold", Float) = 0
        _DepthNormalThresholdScale("DepthNormalThresholdScale", Float) = 0
        _NormalThreshold("NormalThreshold", Float) = 0
        _NormalLevel("NormalLevel", Float) = 0


    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "Queue" = "Geometry" "RenderPipeline" = "UniversalPipeline" }
        LOD 100

        Pass
        {
            Name  "URPUnlit"
            Tags {"LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma prefer_hlslcc gles  
            #pragma exclude_renderers d3d11_9x 
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

  

            struct appdata
            {
                half4 vertex : POSITION;
                half2 uv : TEXCOORD0;
            };

            struct v2f
            {
                half2 uv : TEXCOORD0;
                half4 vertex : SV_POSITION;
                half4 screenPosition       : TEXCOORD1;
                half3 viewSpaceDir : TEXCOORD2;

            };


            //#define _CameraDepthsTexture _CameraDepthTexture
	        //#define sampler_CameraDepthsTexture sampler_CameraDepthTexture

            CBUFFER_START(UnityPerMaterial)
                TEXTURE2D(_MainTex);
                SAMPLER(sampler_MainTex);
                half4 _OutlineColor;
                half4 _MainTex_ST;
                half4 _MainTex_TexelSize;
                TEXTURE2D(_CameraDepthsTexture);
			    SAMPLER(sampler_CameraDepthsTexture);
			    TEXTURE2D(_CameraDepthsNormalTexture);      
                SAMPLER(sampler_CameraDepthsNormalTexture);
                half4x4 _ClipToView;
                half _OutlineScale;
                half _DepthThreshold;
                half _NormalThreshold;
                half _DepthNormalThreshold;
                half _DepthNormalThresholdScale;
                half _NormalLevel;

            CBUFFER_END

            float Outline(float2 screenSpaceUV, float3 viewSpaceDir)
	        {
		        float halfScaleFloor = floor(_OutlineScale * 0.5);
		        float halfScaleCeil = ceil(_OutlineScale * 0.5);

		        //UVs
		        float2 bottomLeftUV = screenSpaceUV - float2(_MainTex_TexelSize.x, _MainTex_TexelSize.y) * halfScaleFloor;
		        float2 topRightUV = screenSpaceUV + float2(_MainTex_TexelSize.x, _MainTex_TexelSize.y) * halfScaleCeil;
		        float2 bottomRightUV = screenSpaceUV + float2(_MainTex_TexelSize.x * halfScaleCeil, -_MainTex_TexelSize.y * halfScaleFloor);
		        float2 topLeftUV = screenSpaceUV + float2(-_MainTex_TexelSize.x * halfScaleFloor, _MainTex_TexelSize.y * halfScaleCeil);

		        //Depth
		        float depth0 = SAMPLE_DEPTH_TEXTURE(_CameraDepthsTexture, sampler_CameraDepthsTexture, bottomLeftUV).x;
		        float depth1 = SAMPLE_DEPTH_TEXTURE(_CameraDepthsTexture, sampler_CameraDepthsTexture, topRightUV).x;
		        float depth2 = SAMPLE_DEPTH_TEXTURE(_CameraDepthsTexture, sampler_CameraDepthsTexture, bottomRightUV).x;
		        float depth3 = SAMPLE_DEPTH_TEXTURE(_CameraDepthsTexture, sampler_CameraDepthsTexture, topLeftUV).x;
	
		        //Normal
		        float3 normal0 = SAMPLE_TEXTURE2D(_CameraDepthsNormalTexture, sampler_CameraDepthsNormalTexture, bottomLeftUV).rgb;
		        float3 normal1 = SAMPLE_TEXTURE2D(_CameraDepthsNormalTexture, sampler_CameraDepthsNormalTexture, topRightUV).rgb;
		        float3 normal2 = SAMPLE_TEXTURE2D(_CameraDepthsNormalTexture, sampler_CameraDepthsNormalTexture, bottomRightUV).rgb;
		        float3 normal3 = SAMPLE_TEXTURE2D(_CameraDepthsNormalTexture, sampler_CameraDepthsNormalTexture, topLeftUV).rgb;

		        //Calculate
		        float3 viewNormal = SAMPLE_TEXTURE2D(_CameraDepthsNormalTexture, sampler_CameraDepthsNormalTexture, screenSpaceUV).rgb * 2 - 1;
		        float NdotV = 1 - dot(viewNormal, -viewSpaceDir);

		        //Threshold
		        float normalThreshold01 = saturate((NdotV - _DepthNormalThreshold) / (1 - _DepthNormalThreshold));
		        float normalThreshold = normalThreshold01 * _DepthNormalThresholdScale + 1;
		        float depthThreshold = _DepthThreshold * depth0 * normalThreshold;


		        //Depth EdgeDetect
		        float depthFiniteDifference0 = depth1 - depth0;
		        float depthFiniteDifference1 = depth3 - depth2;

		        //Cal DepthEdge
		        float edgeDepth = sqrt(pow(depthFiniteDifference0, 2) + pow(depthFiniteDifference1, 2)) * 100;
		        edgeDepth = edgeDepth > (depthThreshold) ? 1 : 0;

		        //DepthNormal EdgeDetect
		        float3 normalFiniteDifference0 = normal1 - normal0;
		        float3 normalFiniteDifference1 = normal3 - normal2;

		        //Cal DepthNormalEdge
		        float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));
		        edgeNormal = pow(edgeNormal * _NormalLevel, 4);

		        edgeNormal = edgeNormal > _NormalThreshold ? 1 : 0;

		        //Result
		        return max(edgeDepth, edgeNormal * _NormalLevel);
		    }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.screenPosition = ComputeScreenPos(o.vertex);

                o.viewSpaceDir = mul(_ClipToView, o.vertex).xyz;

                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                float2 screenUV = (i.screenPosition.xy / i.screenPosition.w);
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float outline = 0;
      
                outline = Outline(screenUV, i.viewSpaceDir);
                /*
                half sobel = SobelDepth(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv, _Thickness, depth0);
                half3 sobelNormal = SobelNormal(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, i.uv, _Thickness, normal0);
                sobelNormal = pow(saturate(sobelNormal) * 1.5, 3);

                */

                return lerp(col, col * _OutlineColor, outline);

            }
            ENDHLSL
        }
    }
}
