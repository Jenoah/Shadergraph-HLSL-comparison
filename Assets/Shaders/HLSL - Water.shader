Shader "Custom/HLSL - Water"
{
    Properties
    {
        [Header(Colors)]
        [HDR] _WaterColorShallow("Water Color - Shallow", Color) = (0,0.5,1,1)
        [HDR] _WaterColorDeep("Water Color - Deep", Color) = (0,0,0.5,1)
        _ClearnessLevel("Clearness Level", Float) = 1.0
        _ClearnessFeather("Clearness Feather", Float) = 0.5
        _Smoothness ("Reflectivity", Range(0,1)) = 0.5

        //Waves
        [Header(Waves)]
        _WavesMoveSpeed ("Waves Move Speed", float) = 0.5
        _WavesScale ("Waves Scale", float) = 0.3
        _WavesIntensity ("Waves Intensity", float) = 10
        _WavesNoiseMap ("Waves Noise Map", 2D) = "gray" {}

        //Normals
        [Header(Normals)]
        _WavesNormalMap1 ("Waves - Normal map 1", 2D) = "bump" {}
        _WavesNormalMap2 ("Waves - Normal map 2", 2D) = "bump" {}
        _WavesNormalMapScale1 ("Waves - Normal map scale 1", Vector) = (5,5,0,0)
        _WavesNormalMapScale2 ("Waves - Normal map scale 2", Vector) = (4,4,0,0)
        _WavesNormalMapStrength ("Waves - Normal map strength", Range(0, 1)) = 0.5
        _WavesNormalMapScrollSpeed ("Waves - Normal map scroll speed", Vector) = (1,1,0,0)
        
        //Refraction
        [Header(Refraction)]
        _Refraction ("Refraction", float) = 0.5
        
        //Fresnel
        [Header(Fresnel)]
        _FresnelPower ("Fresnel Power", float) = 0.5
        
        [Header(Subsurface scattering)]
        _SubsurfaceScatteringIntensity ("Subsurface Scattering Intensity", float) = 0.5
        _SubsurfaceScatteringPower ("_SubsurfaceScatteringPower", float) = 1
        _SubsurfaceScatteringScale ("_SubsurfaceScatteringScale", float) = 2
        
        //Foam
        [Header(Foam)]
        _FoamTexture ("Foam Texture", 2D) = "white" {}
        _FoamDistance ("Foam Distance", float) = 0.5
        _FoamMoveSpeed ("Foam Move Speed", Vector) = (1, 1, 0, 0)
        _FoamScale ("Foam Scale", float) = 1

    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue" = "Transparent"
        }

        Pass
        {
            Tags { "LightMode"="UniversalForward" }
            
            Blend SrcAlpha OneMinusSrcAlpha
		    Cull False
		    ZWrite True
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            //Vertex variables
            struct Attributes
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            //Fragment variables
            struct Varyings
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float3 worldTangent : TEXCOORD3;
                float3 worldBinormal : TEXCOORD4;
                float4 screenPos    : TEXCOORD5;
            };
            
            TEXTURE2D(_WavesNoiseMap); SAMPLER(sampler_WavesNoiseMap);
            TEXTURE2D(_WavesNormalMap1); SAMPLER(sampler_WavesNormalMap1);
            TEXTURE2D(_WavesNormalMap2); SAMPLER(sampler_WavesNormalMap2);
            TEXTURE2D(_CameraColorTexture); SAMPLER(sampler_CameraColorTexture);
            TEXTURE2D(_FoamTexture); SAMPLER(sampler_FoamTexture);
            //TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);


            float _WavesMoveSpeed;
            float _WavesIntensity;
            float _WavesScale;
            float _Smoothness;
            float _WavesNormalMapStrength;
            float _ClearnessLevel;
            float _ClearnessFeather;
            float _Refraction;
            float _FoamDistance;
            float _FoamScale;
            float _FresnelIntensity;
            float _FresnelPower;
            float _SubsurfaceScatteringIntensity;
            float _SubsurfaceScatteringPower;
            float _SubsurfaceScatteringScale;
            float2 _WavesNormalMapScrollSpeed;
            float2 _WavesNormalMapScale1;
            float2 _WavesNormalMapScale2;
            float2 _FoamMoveSpeed;
            float4 _WavesTiling;
            float4 _WaterColorShallow;
            float4 _WaterColorDeep;
            
            float4 _Color;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 worldPos = mul(unity_ObjectToWorld, IN.vertex).xyz;
                
                //Waves
                float waveSpeed = _WavesMoveSpeed * _Time;
                
                float2 scaledUV = (worldPos.xz - 0.5) * _WavesScale + 0.5;
                float2 scrolledUV = scaledUV + waveSpeed;

                float4 displacedPosition = IN.vertex;

                float yOffset = SAMPLE_TEXTURE2D_LOD(_WavesNoiseMap, sampler_WavesNoiseMap, float4(scrolledUV, 0, 0), 0).r * _WavesIntensity;

                displacedPosition.y += yOffset;

                OUT.pos = TransformObjectToHClip(displacedPosition);
                OUT.uv = IN.uv;
                OUT.worldPos = TransformObjectToWorld(displacedPosition);
                OUT.worldNormal = TransformObjectToWorldNormal(IN.normal);
                OUT.worldTangent = TransformObjectToWorldDir(IN.tangent.xyz);
                OUT.worldBinormal = cross(OUT.worldNormal, OUT.worldTangent) * IN.tangent.w;
                OUT.screenPos = ComputeScreenPos(OUT.pos);

                return OUT;
            }

            // The fragment shader definition.            
            half4 frag(Varyings IN) : SV_Target
            {
                
                
                //Positions and UVs
                float4 screenPosRaw = IN.pos;
                float4 screenPos = IN.screenPos;
                float2 screenUVs = IN.screenPos.xy / IN.screenPos.w;

                //Depths
                float rawDepth = SampleSceneDepth(screenUVs);
                float linearDepth01 = Linear01Depth(rawDepth, _ZBufferParams);
                float sceneDepthEye = LinearEyeDepth(rawDepth, _ZBufferParams);
                float sceneDepthLinearFar = linearDepth01 * _ProjectionParams.z;

                //Colors
                float clearness = screenPosRaw.a + _ClearnessLevel;
                clearness = (sceneDepthLinearFar - clearness) * _ClearnessFeather;
                clearness = clamp(clearness, 0, 1);
                
                half4 waterColor = lerp(_WaterColorShallow, _WaterColorDeep, clearness);
                
                //Normal maps
                float normalMapStrength = lerp(0, _WavesNormalMapStrength, clearness);
                float2 normalScrollSpeed = _Time * _WavesNormalMapScrollSpeed;
                
                float2 normalScaledUV1 = (IN.uv - 0.5) * _WavesNormalMapScale1 + 0.5;
                float2 normalScrolledUV1 = normalScaledUV1 + normalScrollSpeed;
                half4 normalMap1 = (SAMPLE_TEXTURE2D(_WavesNormalMap1, sampler_WavesNormalMap1, normalScrolledUV1));

                float2 normalScaledUV2 = (IN.uv - 0.5) * _WavesNormalMapScale2 + 0.5;
                float2 normalScrolledUV2 = normalScaledUV2 - normalScrollSpeed;
                half4 normalMap2 = (SAMPLE_TEXTURE2D(_WavesNormalMap2, sampler_WavesNormalMap2, normalScrolledUV2));
                
                float4 addedNormalMaps = (normalMap1 + normalMap2) / 2;
                addedNormalMaps = lerp(float4(0.5, 0.5, 1, 1), addedNormalMaps, normalMapStrength);
                float3 combinedNormalMaps = UnpackNormal(addedNormalMaps);
                //combinedNormalMaps = (combinedNormalMaps.rg * normalMapStrength, lerp(1, combinedNormalMaps.b, saturate(normalMapStrength)));

                half3 worldNormal = normalize(IN.worldNormal);
                half3 worldTangent = normalize(IN.worldTangent);
                half3 worldBinormal = normalize(IN.worldBinormal);
                half3 finalNormal = normalize(combinedNormalMaps.x * worldTangent + combinedNormalMaps.y * worldBinormal + combinedNormalMaps.z * worldNormal);

                //Refraction                
                float4 grabPassUV = screenPos;
                grabPassUV.xy += combinedNormalMaps * _Refraction;
                float4 sceneColor = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, grabPassUV.xy / grabPassUV.w);
                sceneColor = saturate(sceneColor);

                float4 refractionFinalColor = sceneColor * waterColor;

                //Foam
                float foamLine = sceneDepthEye - screenPosRaw.a;
                float foamNormalized = 1 - clamp(foamLine / _FoamDistance, 0, 1);

                float2 foamSpeed = sin(_Time) * _FoamMoveSpeed;
                float2 foamScaledUV = (IN.uv - 0.5) * _FoamScale + 0.5;
                float2 foamScrolledUV = foamScaledUV + foamSpeed;
                float4 foamColor = SAMPLE_TEXTURE2D(_FoamTexture, sampler_FoamTexture, foamScrolledUV);

                float4 foamFinalColor = foamNormalized * foamColor;

                //Fresnel
                half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - IN.worldPos.xyz);
                float3 fresnel = pow((1.0 - saturate(dot(normalize(finalNormal), normalize(viewDir)))), _FresnelPower);
                
                //Subsurface
                // half3 lightDir = normalize(_MainLightPosition.xyz);
                // float3 H = normalize(lightDir + finalNormal * _SubsurfaceScatteringIntensity);
                // float VdotH = pow(saturate(dot(viewDir, -H)), _SubsurfaceScatteringPower) * _SubsurfaceScatteringScale;
                // float3 subsurfaceColor = _MainLightColor.rgb * (VdotH + waterColor) * 1;

                float3 finalColor = lerp(refractionFinalColor, (1,1,1,1), foamFinalColor);
                //finalColor += subsurfaceColor;
                finalColor += fresnel;
                
                
                // PBR lighting calculations
                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = finalColor;
                surfaceData.normalTS = finalNormal;
                surfaceData.metallic = 0;
                surfaceData.smoothness = _Smoothness;
                surfaceData.occlusion = 1;
                //surfaceData.alpha = 1;
                surfaceData.alpha = waterColor.a;

                // Calculate lighting
                InputData inputData = (InputData)0;
                inputData.positionWS = IN.worldPos;
                inputData.normalWS = finalNormal;
                //inputData.normalWS = IN.worldNormal;
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.worldPos);
                inputData.shadowCoord = TransformWorldToShadowCoord(IN.worldPos);
                #if UNITY_VERSION >= 202120
	            inputData.positionCS = IN.pos;
                #endif

                half4 color = UniversalFragmentPBR(inputData, surfaceData);
                
                return color;
            }
            ENDHLSL
        }
    }
    //FallBack "Diffuse"
}