Shader "Custom/MosaicLEDShader"
{
    Properties
    {
        _MainTex2 ("Texture", 2D) = "white" {}
        _ChunkSize ("Chunk Size", Range(1, 64)) = 8 // 청크 크기 (예: 8x8 픽셀)
        _OuterRadius ("Outer Radius", Range(0.0, 0.5)) = 0.45 // 원의 바깥쪽 반경 (0.0에서 0.5 사이)
        _InnerRadius ("Inner Radius", Range(0.0, 0.5)) = 0.0 // 원의 안쪽 반경 (0.0에서 0.5 사이)
        _Brightness ("Brightness", Range(0.0, 5.0)) = 1.0 // 전체 밝기 조절 (외부 링에만 적용)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
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
            sampler2D _MainTex2;
            float4 _MainTex2_ST;
            float _ChunkSize;
            float _OuterRadius;
            float _InnerRadius;
            float _Brightness;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex2);
                return o;

            }
            fixed4 frag (v2f i) : SV_Target
            {
                // 픽셀의 화면 해상도를 기반으로 UV 좌표를 픽셀 단위로 변환
                float2 pixelCoords = i.uv * _ScreenParams.xy;
                // 픽셀을 청크로 그룹화
                // 현재 픽셀이 속한 청크의 좌상단 픽셀 좌표를 계산
                float2 chunkCoords = floor(pixelCoords / _ChunkSize) * _ChunkSize;
                // 청크의 중앙 픽셀의 UV 좌표를 계산 (청크 내 모든 픽셀이 이 값을 사용)
                float2 chunkUV = (chunkCoords + _ChunkSize * 0.5) / _ScreenParams.xy;
                // 청크의 중심에서 현재 픽셀까지의 상대적인 위치 계산
                // 이를 통해 청크 내에서 원형 효과를 적용할 수 있음
                float2 chunkLocalCoords = (pixelCoords - chunkCoords) / _ChunkSize;
                // 0.0에서 1.0 범위의 좌표를 -0.5에서 0.5 범위로 변환하여 중심을 0으로 만듦
                chunkLocalCoords -= float2(0.5, 0.5);
                // 청크 중심으로부터의 거리 계산
                float dist = length(chunkLocalCoords);
                // 픽셀화된 색상 가져오기
                fixed4 col = tex2D(_MainTex2, chunkUV);
                // 원 안쪽(_InnerRadius 이하)은 원래 청크 색상
                if (dist <= _InnerRadius) {
                    return col;
                }
                // 원 바깥쪽(_OuterRadius 초과)은 검은색
                else if (dist > _OuterRadius) {
                    return fixed4(0, 0, 0, 1);
                }
                // 원 사이 영역은 LED 효과 적용 (밝기 조절)
                else {
                    // 원형 마스크 계산 (바깥쪽으로 갈수록 강도 증가)
                    // *InnerRadius에서 1.0 (원본 밝기)으로 시작하여 *OuterRadius로 갈수록 _Brightness에 가까워짐
                    float normalizedDist = (dist - _InnerRadius) / (_OuterRadius - _InnerRadius);
                    float intensity = 1.0 + normalizedDist * (_Brightness - 1.0); // 1.0 (원본)에서 _Brightness로 보간
                    col.rgb *= intensity;
                    return col;
                }
            }
            ENDCG
        }
    }
}