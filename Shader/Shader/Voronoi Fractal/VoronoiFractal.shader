Shader "Unlit/VoronoiFractal"
{
    //Reference
    //https://www.shadertoy.com/view/MldSz8
    //https://iquilezles.org/articles/voronoilines/
    //https://danielilett.com/2023-06-20-tut7-2-voronoi-lava/
    //https://cyangamedev.wordpress.com/2019/07/16/voronoi/

    Properties
    {
        _MainTex("Main Tex", 2D) = "white" {}
        _CellDensity("Cell Density", Range(1, 100)) = 20
        _EdgeThreshold("Edge Threshold", Range(0.001, 0.1)) = 0.01
        _EdgeSmoothness("Edge Smoothness", Range(0.001, 0.1)) = 0.02
        _Iterations ("Iterations", Range(1, 8)) = 2
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
                TEXTURE2D(_MainTex);
                SAMPLER(sampler_MainTex);
                float _CellDensity;
                float _EdgeThreshold;
                float _EdgeSmoothness;
                uint _Iterations;
            CBUFFER_END

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }
float hash11(float x)
{
    return frac(sin(x * 12.9898) * 43758.5453);
}
            float2 randomVector(int2 seed, float2 angleOffset)
            {
                float2 rnd = frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
                float2 angle = angleOffset + rnd.x * 6.28318;
                return float2(cos(angle.x), sin(angle.y)) * rnd.y;
            }

            inline float2 voronoi_noise_randomVector (float2 UV, float2 offset)
            {
                float2x2 m = float2x2(15.27, 47.63, 99.41, 89.98);
                UV = frac(sin(mul(UV, m)) * 46839.32);
                return float2(sin(UV.y*+offset.x)*0.5+0.5, cos(UV.x*offset.y)*0.5+0.5);
            }
 
            void Voronoi_float(float2 UV, float2 AngleOffset, float CellDensity, out float Out, out float Cells) 
            {
                float2 g = floor(UV * CellDensity);
                float2 f = frac(UV * CellDensity);
                float2 res = float2(8.0, 8.0);
                float2 ml = float2(0,0);
                float2 mv = float2(0,0);
 
                for(int y=-1; y<=1; y++){
                    for(int x=-1; x<=1; x++){
                        float2 lattice = float2(x, y);
                        float2 offset = voronoi_noise_randomVector(g + lattice, AngleOffset);
                        float2 v = lattice + offset - f;
                        float d = dot(v, v);
 
                        if(d < res.x){
                            res.x = d;
                            res.y = offset.x;
                            mv = v;
                            ml = lattice;
                        }
                    }
                }
                Cells = res.y;
 
                res = float2(8.0, 8.0);
                for(int y=-2; y<=2; y++){
                    for(int x=-2; x<=2; x++){
                        float2 lattice = ml + float2(x, y);
                        float2 offset = voronoi_noise_randomVector(g + lattice, AngleOffset);
                        float2 v = lattice + offset - f;
 
                        float2 cellDifference = abs(ml - lattice);
                        if (cellDifference.x + cellDifference.y > 0.1){
                            float d = dot(0.5*(mv+v), normalize(v-mv));
                            res.x = min(res.x, d);
                        }
                    }
                }
                Out = res.x;
            }

            half4 frag (v2f i) : SV_Target
            {
                float4 mainTex = SAMPLE_TEXTURECUBE(_MainTex, sampler_MainTex, i.uv);

                float3 color = float3(1,1,1);
                float voronoi = 0;
                float cells = 0;
                float totalEdge = 1;

                float s = 0;
                float2 uv = i.uv;
                float2 angleOffset = _Time.y * .001;

                for(int index = 0; index < _Iterations; index++)
                {
                    float v;

                    float2 angle = angleOffset;
                    angleOffset *= s / (index + 1);

                    Voronoi_float(uv + s, 5 + angleOffset, _CellDensity * (index + 1), v, cells);
                    s += cells * (2);

                    float edge = smoothstep(_EdgeThreshold * ((_Iterations - index) * .75 / _Iterations), 
                    _EdgeThreshold + _EdgeSmoothness* ((_Iterations - index) * .75 / _Iterations), (v));

                    if(index % 3 == 0)
                    {
                        color.x *= cells * .5 + .5;
                    }
                    else if(index % 3 == 1)
                    {
                        color.y *= cells* .5 + .5;
                    }
                    else
                    {
                        color.z *= cells* .5 + .5;
                    }

                    totalEdge = 1 - max(1 - totalEdge, (1 - edge) * pow((_Iterations - index * .5)/ _Iterations, .5));
                }

                //return totalEdge;
                return float4(lerp(float3(0,0,0), color, totalEdge), 1);
 
                //return edge;
                float3 final = lerp(0, float3(saturate(cells + 0.01), cells, cells), totalEdge);

                return float4(final, 1) ;
            }
            ENDHLSL
        }
    }
}