Shader "Mike/RayMarchLit_youtube 1"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        // Cull Off ZWrite Off ZTest Always
        Tags {"Queue"="Transparent"}
        

        Pass{
            Tags {"LightMode" = "ForwardBase"}
            Blend SrcAlpha OneMinusSrcAlpha
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                // float3 normal: NORMAL;
            };

            struct v2f
            {
                float3 wPos : TEXCOORD1;
                float4 pos : SV_POSITION; 
                // fixed4 diff: COLOR0;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            #define STEPS 64
            #define STEP_SIZE 0.01

            bool SphereHit(float3 p, float3 center, float radius)
            {
                return distance(p, center) < radius;
            }

            float3 RaymarchHit(float3 position, float3 direction) {
                for(int i = 0; i < STEPS; i++) {
                    if (SphereHit(position, float3(0,0,0), 0.5))
                        return position;
                    
                    position += direction * STEP_SIZE;
                }
                // Depth
                return float3(0,0,0);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 worldPosition = i.wPos;
                float3 viewDirection = normalize(i.wPos - _WorldSpaceCameraPos);
                float3 depth = RaymarchHit(worldPosition, viewDirection);

                // Normal
                half3 worldNormal = depth - float3(0,0,0);
                half normal = max(0, dot(worldNormal, _WorldSpaceLightPos0.xyz));

                if(length(depth) != 0)
                {
                    depth *= normal * _LightColor0;
                    return fixed4(depth, 1);
                }
                else 
                    return fixed4(1, 1, 1, 0);
            }
            ENDCG
        }
    }
}
