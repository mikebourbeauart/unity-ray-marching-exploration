// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'



Shader "Custom/02RayMarch"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
        _Radius ("Radius", float) = 1
        _Centre ("Centre", float) = 0
    }
    SubShader
    {
        // No culling or depth
        // Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            float _Radius;
            float _Centre;

            #define STEPS 64
            #define STEP_SIZE 0.1
            #define MIN_DISTANCE 0.01
            
            struct appdata
            {
                float4 vertex : POSITION;
                // float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                // float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION; // Clip space
                float3 wPos : TEXCOORD1; // World position
            };

            // Vertex function
            v2f vert (appdata_full v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz; 
                return o;
            }
            	
            // bool sphereHit (float3 p)
            // {
            //     return distance(p,_Centre) < _Radius;
            // }

            float sphereDistance (float3 p)
            {
                return distance(p,_Centre) - _Radius;
            }
	
            fixed4 raymarch (float3 position, float3 direction)
            {
                for (int i = 0; i < STEPS; i++)
                {
                    float distance = sphereDistance(position);
                    if (distance < MIN_DISTANCE)
                        return i / (float) STEPS;
                    
                    position += distance * direction;
                }
                return 0;
            }

            // Fragment function
            fixed4 frag (v2f i) : SV_Target
            {
                float3 worldPosition = i.wPos;
                float3 viewDirection = normalize(i.wPos - _WorldSpaceCameraPos);
                return raymarch (worldPosition, viewDirection);
            }
            ENDCG
        }
    }
}
