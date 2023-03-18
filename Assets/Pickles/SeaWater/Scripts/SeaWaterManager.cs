using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Pickles.SeaWater
{
    [ExecuteAlways]
    public sealed class SeaWaterManager : MonoBehaviour
    {
        [Header("Extinction (Absorption + Scattering)")]
        [SerializeField, Range(0, 1.5f)] float extinctionR = 1;
        [SerializeField, Range(0, 1f)] float extinctionG = 0.02f;
        [SerializeField, Range(0, 1f)] float extinctionB = 0.01f;
        [Header("Absorption Ratio (Absorption / Extinction)")]
        [SerializeField, Range(0, 1)] float absorptionRatioR = 1f;
        [SerializeField, Range(0, 1)] float absorptionRatioG = 0.8f;
        [SerializeField, Range(0, 1)] float absorptionRatioB = 0.2f;

        [SerializeField, Range(3, 5)] float slope = 4f;
        [SerializeField, Range(0, 1)] float ffa = 0.2f;
        [SerializeField, Range(1, 100)] float inScatteringPower = 1;

        static class ShaderProperty
        {
            public static readonly int Extinction = Shader.PropertyToID("_Extinction");
            public static readonly int AbsorptionRatio = Shader.PropertyToID("_AbsorptionRatio");
            public static readonly int Slope = Shader.PropertyToID("_Slope");
            public static readonly int FFa = Shader.PropertyToID("_FFa");
            public static readonly int InScatteringPower = Shader.PropertyToID("_InScatteringPower");
        }


        void LateUpdate()
        {
            Shader.SetGlobalVector(ShaderProperty.Extinction, new Vector3(extinctionR, extinctionG,extinctionB));
            Shader.SetGlobalVector(ShaderProperty.AbsorptionRatio, new Vector3(absorptionRatioR, absorptionRatioG, absorptionRatioB));
            Shader.SetGlobalFloat(ShaderProperty.Slope, slope);
            Shader.SetGlobalFloat(ShaderProperty.FFa, ffa);
            Shader.SetGlobalFloat(ShaderProperty.InScatteringPower, inScatteringPower);
        }
    }
}
