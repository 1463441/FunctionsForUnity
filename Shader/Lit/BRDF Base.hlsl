
// ==================== Struct Definitions ====================

struct SurfaceStruct {
    half3 albedo;                        // Albedo color
    half3 diffuse;                       // Diffuse color
    half3 specular;                      // Specular color
    half3 indirectSample;                // IBL/specular indirect
    half  metallic;                      // Metallic value
    half  smoothness;                    // Smoothness value
    half3 ambient;                       // Ambient color
    half  ambientOcclusion;              // AO mask
    half  shadowAttenuation;             // Shadow strength
    half  additionalShadowAttenuation;   // Additional shadow (e.g., AO * baked)
    half3 normalTS;                      // Tangent-space normal
    half3 emission;                      // Emission
    half  alpha;                         // Alpha
};

struct BRDF_Struct {
    float3 N;          // Normal
    float3 V;          // View vector
    float3 L;          // Light vector
    float3 H;          // Half vector
    float NdotL;       // N·L
    float NdotV;       // N·V
    float NdotH;       // N·H
    float HdotV;       // H·V
    float LdotH;       // L·H
    float NDF;         // Normal Distribution Function
    float GSF;         // Geometric Shadowing Function
    float Fresnel;     // Fresnel term
    float diffuseTerm; // Disney Diffuse
};

// ==================== Helper Functions ====================

float3 ComputeNormal(float2 uv) {
    float3 normalTS = UnpackNormal(tex2D(_NormalMap, uv)); // TS normal
    float3 normalWS = normalize(mul((float3x3)unity_TangentToWorld, normalTS));
    return normalWS;
}

void ComputeLight(inout SurfaceStruct s, float3 posWS, float3 normalWS) {
    float3 lightColor = 0;
    float shadow = 1.0;

    // Main Light
    Light mainLight = GetMainLight();
    float3 L = normalize(mainLight.direction);
    float NoL = saturate(dot(normalWS, L));
    shadow = mainLight.shadowAttenuation * mainLight.distanceAttenuation;
    lightColor += mainLight.color * NoL * shadow;

    // Additional Lights
    uint lightCount = GetAdditionalLightsCount();
    for (uint i = 0; i < lightCount; i++) {
        Light light = GetAdditionalLight(i);
        float3 L2 = normalize(light.direction);
        float NoL2 = saturate(dot(normalWS, L2));
        float attenuation = light.shadowAttenuation * light.distanceAttenuation;
        lightColor += light.color * NoL2 * attenuation;
    }

    s.shadowAttenuation = shadow;
    s.additionalShadowAttenuation = shadow; // Placeholder, expand as needed
    s.ambient = lightColor; // Light sum for ambient contribution
}

void ComputeSample(inout SurfaceStruct s, float2 uv) {
    // Smoothness
    #if defined(_ROUGHTYPE_SMOOTHNESS_MAP)
        s.smoothness = tex2D(_SmoothnessMap, uv).r;
    #elif defined(_ROUGHTYPE_ROUGHNESS_MAP)
        s.smoothness = 1.0 - tex2D(_SmoothnessMap, uv).r;
    #else
        s.smoothness = _Smoothness;
    #endif

    // Metallic or Specular
    #if defined(_SURFACETYPE_SPECULAR)
        s.metallic = 0;
        s.specular = tex2D(_SpecColorMap, uv).rgb;
    #elif defined(_SURFACETYPE_METALLIC)
        s.metallic = tex2D(_MetallicMap, uv).r;
        s.specular = lerp(0.04, s.albedo, s.metallic);
    #else
        s.metallic = _Metallic;
        s.specular = lerp(0.04, s.albedo, s.metallic);
    #endif

    // AO
    s.ambientOcclusion = tex2D(_AOMAP, uv).r;
}

void ComputeSurface(inout SurfaceStruct s, float2 uv) {
    s.albedo = tex2D(_BaseMap, uv).rgb;
    s.emission = tex2D(_EmissionMap, uv).rgb;
    s.alpha = tex2D(_BaseMap, uv).a;
    s.normalTS = UnpackNormal(tex2D(_NormalMap, uv));
}

void ComputeBRDF(inout BRDF_Struct brdf, SurfaceStruct s, float3 normalWS, float3 viewWS, float3 lightDirWS) {
    brdf.N = normalWS;
    brdf.V = viewWS;
    brdf.L = lightDirWS;
    brdf.H = normalize(viewWS + lightDirWS);
    brdf.NdotL = saturate(dot(brdf.N, brdf.L));
    brdf.NdotV = saturate(dot(brdf.N, brdf.V));
    brdf.NdotH = saturate(dot(brdf.N, brdf.H));
    brdf.HdotV = saturate(dot(brdf.H, brdf.V));
    brdf.LdotH = saturate(dot(brdf.L, brdf.H));

    float a = max(0.001, s.smoothness * s.smoothness);
    float a2 = a * a;

    float denom = (brdf.NdotH * brdf.NdotH) * (a2 - 1) + 1;
    brdf.NDF = a2 / (PI * denom * denom + 1e-5);

    float G_V = brdf.NdotV / (brdf.NdotV * (1 - a * 0.5) + a * 0.5);
    float G_L = brdf.NdotL / (brdf.NdotL * (1 - a * 0.5) + a * 0.5);
    brdf.GSF = G_V * G_L;

    float3 F0 = s.specular;
    brdf.Fresnel = F0 + (1 - F0) * pow(1 - brdf.HdotV, 5);

    float FL = pow(1 - brdf.NdotL, 5);
    float FV = pow(1 - brdf.NdotV, 5);
    float Fd90 = 0.5 + 2.0 * brdf.LdotH * brdf.LdotH * a;
    brdf.diffuseTerm = (1 + (Fd90 - 1) * FL) * (1 + (Fd90 - 1) * FV);
}

float4 Compute(float2 uv, float3 posWS, float3 viewWS, float3 lightDirWS) {
    SurfaceStruct s;
    ComputeSurface(s, uv);
    ComputeSample(s, uv);
    float3 normalWS = ComputeNormal(uv);
    s.indirectSample = texCUBE(_SpecCube, normalWS).rgb; // IBL
    ComputeLight(s, posWS, normalWS);

    BRDF_Struct brdf;
    ComputeBRDF(brdf, s, normalWS, viewWS, lightDirWS);

    float3 diffuse = s.diffuse * brdf.diffuseTerm * brdf.NdotL;
    float3 specular = brdf.Fresnel * brdf.NDF * brdf.GSF / (4 * brdf.NdotV * brdf.NdotL + 1e-4);
    float3 indirect = s.indirectSample * brdf.Fresnel;

    float3 finalColor = (diffuse + specular + indirect) * s.ambientOcclusion * s.ambient + s.emission;

    return float4(finalColor, s.alpha);
}

