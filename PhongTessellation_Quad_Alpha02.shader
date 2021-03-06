﻿// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/PhongTessellation_Quad_Alpha02"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}
		_NormalTex("Normalmap", 2D) = "bump" {}
		_DispTex("Disp Texture", 2D) = "gray" {}
		_MaxDisplacement("Max Displacement", Range(0, 1.0)) = 0.3
		_SubdivisionAmount("Subivision Amount", Range(1, 5)) = 1
		_Color("Color", Color) = (1,1,1,1)
		_Metallic("Metallic", Range(0, 1)) = 1
		_Gloss("Gloss", Range(0, 1)) = 0.8
		_Ambient_Multiplier("Ambient Multiplier", Float) = 5
	}

	SubShader
	{
		Pass
		{
			Tags {"LightMode" = "Deferred"}

			CGPROGRAM
			#pragma vertex vertex_shader
			#pragma hull hull_shader
			#pragma domain domain_shader
			#pragma fragment pixel_shader
			#pragma multi_compile ___ UNITY_HDR_ON
			//#pragma exclude_renderers nomrt
			#pragma target 4.6
			#pragma glsl

			//#define UNITY_PASS_DEFERRED
			#include "UnityPBSLighting.cginc"
			//#include "HLSLSupport.cginc"
			//#include "UnityShaderVariables.cginc"
			//#include "Lighting.cginc"
			//#include "AutoLight.cginc"

			//#pragma only_renderers d3d11

			uniform sampler2D _LightBuffer;

			int _SubdivisionAmount;
			float _MaxDisplacement;

			float4 _Color;
			float _Metallic;
			float _Gloss;
			float _Ambient_Multiplier;

			sampler2D _MainTex;
			SamplerState sampler_MainTex;
			uniform float4 _MainTex_ST;
			uniform float4 _NormalTex_ST;
			uniform float4 _DispTex_ST;
			
			float2 uv_MainTex;

			sampler2D _NormalTex;
			SamplerState sampler_NormalTex;

			sampler2D _DispTex;
			SamplerState sampler_DispTex;

			//struct Input 
			//{
			//	float2 uv_MainTex;
			//	float2 uv_NormalTex;
			//};

			// First Vertex Output.
			struct VS_OUTPUT
			{
				float4 position : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD;
			};

			// Tessellation Vertex Output.
			struct HS_OUTPUT
			{
				float4 position : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD;
			};

			struct HS_CONSTANT_DATA_OUTPUT
			{
				float Edges[4] : SV_TessFactor;
				float Inside[2] : SV_InsideTessFactor;
			};

			//float4 vertex_shader(float4 vertex:POSITION) : POSITION
			//{
			//	return mul(UNITY_MATRIX_MV, vertex);
			//	//return UnityObjectToViewPos(vertex.xyz);
			//}

			// Apparently this uses VS_OUTPUT, but step is redundant.
			void vertex_shader(inout VS_OUTPUT v) {
				HS_OUTPUT hsOut;

				hsOut.position = v.position;
				hsOut.normal = v.normal;
				//hsOut.normal = UnityObjectToWorldNormal(v.normal);
				hsOut.uv = v.uv;
			}

			HS_CONSTANT_DATA_OUTPUT constantsHS(InputPatch<VS_OUTPUT, 4> patch)
			{
				HS_CONSTANT_DATA_OUTPUT output;
				output.Edges[0] = output.Edges[1] = output.Edges[2] = output.Edges[3] = _SubdivisionAmount;
				output.Inside[0] = output.Inside[1] = _SubdivisionAmount;
				return output;
			}

			// I think this is what they mean by fixedfunction. The tessellation part is fixedfunction.
			[domain("quad")]
			[partitioning("integer")] // [partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[outputcontrolpoints(4)]
			[patchconstantfunc("constantsHS")]
			HS_OUTPUT hull_shader(InputPatch<VS_OUTPUT, 4> patch, uint id : SV_OutputControlPointID)//, uint pid : SV_PrimitiveID)
			{
				return patch[id];

				/*
				HS_OUTPUT output;

				output.position = patch[id].position;
				output.normal = patch[id].normal;
				output.uv = patch[id].uv;

				return output;
				*/
			}


			// Declare GBuffers.
			// Apparently the float value doesn't have hdr, but half4 does.
			struct structurePS
			{
				float4 albedo : SV_Target0;
				float4 specular : SV_Target1;
				float4 normal : SV_Target2;
				float4 emission : SV_Target3;
				//float depthSV : Depth;
			};

			struct DS_OUTPUT
			{
				float4 position : SV_POSITION;
				float3 normal	: NORMAL;
				float2 texcoord	: TEXCOORD1;
				//float3 posworld : POSITION; // Causes errors in Domain Shader.
			};

			// q = lerped position according to SV_DomainLocation.
			// p = patch position, in sequential order [0], [1], etc...
			// n = patch normal, in sequential order [0], [1], etc...
			float3 PhongOperator(float3 q, float3 p, float3 n)
			{
				return q - dot(q - p, n) * n;
			}

			// DOMAIN SHADER.
			// We process displacement in here apparently... Used to be a lot of things, a vertex struct, a pixel struct, this is the new one.
			// a = top Mid Position.
			// b = bottom Mid Position.
			[domain("quad")]
			DS_OUTPUT domain_shader(HS_CONSTANT_DATA_OUTPUT input, const OutputPatch<HS_OUTPUT, 4> patch, float2 UV : SV_DomainLocation)// : SV_POSITION
			{
				DS_OUTPUT output;

				// Bilinear interpolation of position.
				float3 a = lerp(patch[0].position, patch[1].position, UV.x);
				float3 b = lerp(patch[3].position, patch[2].position, UV.x);

				float3 newPosition = lerp(a, b, UV.y);

				// Phong Operator and Bilinear interpolation of results for new position.
				float3 c0 = PhongOperator(newPosition, patch[0].position.xyz, patch[0].normal);
				float3 c1 = PhongOperator(newPosition, patch[1].position.xyz, patch[1].normal);
				float3 c2 = PhongOperator(newPosition, patch[2].position.xyz, patch[2].normal);
				float3 c3 = PhongOperator(newPosition, patch[3].position.xyz, patch[3].normal);

				float3 phong_a = lerp(c0, c1, UV.x);
				float3 phong_b = lerp(c3, c2, UV.x);

				// We use this to sample the displacement map.
				float3 phongNew = lerp(newPosition, lerp(phong_a, phong_b, UV.y), 0.75 /* alpha parameter, default = 3/4 */);
				// Works better in here than in vertex shader.
				// If we don't want to use a displacement map we just use this and comment out the vertex displacement below.
				//output.position = UnityObjectToClipPos(float4(phongNew, 1));

				// Bilinear interpolation of normals.
				float3 normal_a = lerp(patch[0].normal, patch[1].normal, UV.x);
				float3 normal_b = lerp(patch[3].normal, patch[2].normal, UV.x);
				
				// Output Data.
				output.normal = lerp(normal_a, normal_b, UV.y);
				//output.normal = UnityObjectToWorldNormal(output.normal);

				// Bilinear interpolation of Texcoords/UV's
				float2 uv_a = lerp(patch[0].uv, patch[1].uv, UV.x);
				float2 uv_b = lerp(patch[3].uv, patch[2].uv, UV.x);

				output.texcoord = lerp(uv_a, uv_b, UV.y);

				// This kinda works?
				//float3 disp = _DispTex.SampleLevel(sampler_DispTex, output.texcoord, 0).rgb * _Displacement;

				// Get Colour from displacement map, and convert to float from 0 to _MaxDisplacement.
				float4 dispTexColour = tex2Dlod(_DispTex, float4(output.texcoord, 0.0, 0.0));
				float displacement = dot(float3(0.21, 0.72, 0.07), dispTexColour.rgb) * _MaxDisplacement;

				// Displace vertices along surface normal vector.
				float3 newVertexPos = phongNew + float4(output.normal * displacement, 0.0);

				// Output data.
				output.position = UnityObjectToClipPos(float4(newVertexPos, 1));
				output.normal = UnityObjectToWorldNormal(output.normal);


				// Trash
				//output.position.xyz += UnityObjectToClipPos(newVertexPos.xyz);//UnityObjectToClipPos(newVertexPos +phongNew);
				//output.position.xyz += newVertexPos.xyz;
				//dispTexColour =  UnityObjectToClipPos(dispTexColour);
				//float displacement = dot(float3(0.21, 0.72, 0.07), dispTexColour.rgb) * _Displacement;
				//float displacement =  //dot(output.normal.xyz, dispTexColour.rgb) * _Displacement;
				//float displacement = (dispTexColour.r * output.normal.x + dispTexColour.g * output.normal.y + dispTexColour.b * output.normal.z);
				//output.position.xyz +=  displacement * _Displacement;
				//output.position.xyz = UnityObjectToClipPos(output.position.xyz);

				return output;

			}

			// Original, still works.
			//float4 pixel_shader(float4 color:SV_POSITION) : SV_TARGET
			//{
			//	return float4(1.0,0.0,0.0,1.0);
			//}

			float _Distortion;
			float _Power;
			float _Scale;

			inline float4 LightingStandardTranslucent(SurfaceOutputStandard s, float3 viewDir, UnityGI gi)
			{
				// Original colour.
				float4 pbr = LightingStandard(s, viewDir, gi);
				//float4 pbr = ps.albedo;

				// Calculate intensity of backlight (light translucent)
				//float i = 

				float3 L = gi.light.dir;
				float3 V = viewDir;
				float3 N = s.Normal;

				float3 H = normalize(L + N * _Distortion);
				float I = pow(saturate(dot(V, -H)), _Power) * _Scale;

				// Final add
				pbr.rgb = pbr.rgb + gi.light.color * I;
				return pbr;
			}

			float3 ProcessEmission(float3 colourInput)
			{
				// Return Emissive GBuffer.
				float4 emissionTemp = float4(0, 0, 0, 1);

				float3 indirectDiffuse = float3(0, 0, 0);
				indirectDiffuse += UNITY_LIGHTMODEL_AMBIENT.rgb;

				// Original was ps.emission.rgb += indirectDiffuse * (colourFloat4.rgb) * _Ambient_Multiplier;
				return emissionTemp.rgb += indirectDiffuse * colourInput * _Ambient_Multiplier;
			}

			structurePS pixel_shader(DS_OUTPUT input) : SV_Target
			{
				SurfaceOutputStandard o;
				structurePS deferredStruct;
				deferredStruct.albedo = tex2D(_MainTex, input.texcoord);//  *_Color;
				//deferredStruct.albedo = tex2D(_LightBuffer, input.texcoord);
				deferredStruct.albedo.a = 1;

				UnityGI gi;
				//deferredStruct.albedo = LightingStandardTranslucent(o, float3(1,0,0), gi);
				//deferredStruct.albedo.a = 1;

				// Specular.
				//deferredStruct.specular = float4(1,1,1,1);//float4(1, 1, 1, 1);
				deferredStruct.specular = float4(float3(1,1,1), _Gloss);
				//deferredStruct.emission = float4(1, 1, 1, 1);

				// Normal.
				//deferredStruct.normal = tex2D(_NormalTex, input.texcoord);// float4(1, 1, 1, 1);
				float3 unpackNormal = UnpackNormal(tex2D(_NormalTex, input.texcoord));

				deferredStruct.normal.xyz = normalize(input.normal);
				deferredStruct.normal = float4(deferredStruct.normal.xyz * 0.5 + 0.5, 1);
				//deferredStruct.normal = float4(float3(deferredStruct.normal.x * -1, deferredStruct.normal.yz) * 0.5 + 0.5, 1);

				// Emission.
				// Return Emissive GBuffer.
				deferredStruct.emission = float4(0, 0, 0, 1);
				deferredStruct.emission.rgb = ProcessEmission(deferredStruct.albedo.rgb);

				#ifndef UNITY_HDR_ON
				deferredStruct.emission.rgb = exp2(-deferredStruct.emission.rgb);
				#endif

				return deferredStruct;
			}

			ENDCG
		}
	}
	Fallback "Diffuse"

}