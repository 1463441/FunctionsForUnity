
            // Disney Diffuse 함수
float DisneyDiffuse(float NdotV, float NdotL, float LdotH, float perceptualRoughness)
{
    float FD90 = 0.5 + 2.0 * LdotH * LdotH * perceptualRoughness;
    float lightScatter = 1.0 + (FD90 - 1.0) * pow(1.0 - NdotL, 5.0);
    float viewScatter  = 1.0 + (FD90 - 1.0) * pow(1.0 - NdotV, 5.0);
    return lightScatter * viewScatter * (1.0 / PI);
}

// Schlick Fresnel
float3 F_Schlick(float3 F0, float VdotH)
{
    return F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0);
}

// GGX Normal Distribution Function
float D_GGX(float NdotH, float roughness)
{
    float a = roughness * roughness;
    float a2 = a * a;
    float d = (NdotH * NdotH) * (a2 - 1.0) + 1.0;
    return a2 / (PI * d * d + 1e-5);
}

// Smith's Geometry Function
float G_Smith(float NdotV, float NdotL, float roughness)
{
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    float Gv = NdotV / (NdotV * (1.0 - k) + k);
    float Gl = NdotL / (NdotL * (1.0 - k) + k);
    return Gv * Gl;
}

// ComputeBRDF: BRDF_Struct 계산 함수
void ComputeBRDF(inout BRDF_Struct brdf, float3 F0, float roughness)
{
    brdf.NdotL = saturate(dot(brdf.N, brdf.L));
    brdf.NdotV = saturate(dot(brdf.N, brdf.V));
    brdf.NdotH = saturate(dot(brdf.N, brdf.H));
    brdf.HdotV = saturate(dot(brdf.H, brdf.V));
    brdf.LdotH = saturate(dot(brdf.L, brdf.H));

    brdf.NDF = D_GGX(brdf.NdotH, roughness);
    brdf.GSF = G_Smith(brdf.NdotV, brdf.NdotL, roughness);
    brdf.Fresnel = 1.0; // optional legacy fallback
    brdf.diffuseTerm = DisneyDiffuse(brdf.NdotV, brdf.NdotL, brdf.LdotH, roughness);
}

// ComputeSurface: SurfaceStruct 계산 함수
void ComputeSurface(inout SurfaceStruct s, float3 normalWS, float3 viewDirWS, float3 lightDirWS)
{
    s.normalTS = normalWS;
    s.shadowAttenuation = 1.0;
    s.additionalShadowAttenuation = 1.0;
    s.ambientOcclusion = 1.0;
    s.alpha = 1.0;
    s.indirectSample = 0;
    s.ambient = 0;
    s.emission = 0;

    s.diffuse = s.albedo * (1 - s.metallic); // 비금속 성분만 diffuse
    float oneMinusRoughness = 1.0 - s.smoothness;
    float3 baseReflect = lerp(0.04, s.albedo, s.metallic); // F0 보간
    s.specular = baseReflect;
}

// Compute: 최종 색 계산 함수
float4 Compute(SurfaceStruct s, float3 normalWS, float3 viewDirWS, float3 lightDirWS, float3 lightColor)
{
    BRDF_Struct brdf;
    brdf.N = normalize(normalWS);
    brdf.V = normalize(viewDirWS);
    brdf.L = normalize(lightDirWS);
    brdf.H = normalize(brdf.V + brdf.L);

    ComputeSurface(s, normalWS, viewDirWS, lightDirWS);
    ComputeBRDF(brdf, s.specular, 1.0 - s.smoothness);

    float3 F = F_Schlick(s.specular, brdf.HdotV);
    float3 specularTerm = (brdf.NDF * brdf.GSF * F) / max(4.0 * brdf.NdotL * brdf.NdotV, 1e-4);

    float3 color = 0;
    color += s.diffuse * brdf.diffuseTerm * brdf.NdotL;     // 디즈니 디퓨즈
    color += specularTerm * brdf.NdotL;                     // 스펙큘러
    color *= lightColor * s.shadowAttenuation;              // 그림자 적용
    color += s.ambient * s.ambientOcclusion;                // 앰비언트
    color += s.emission;                                    // 발광

    return float4(color, s.alpha);
}
