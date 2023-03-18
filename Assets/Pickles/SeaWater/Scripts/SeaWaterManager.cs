using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Pickles.SeaWater
{
    [ExecuteAlways]
    public sealed class SeaWaterManager : MonoBehaviour
    {
        [SerializeField] Vector3 extinction;
        [SerializeField] Vector3 absorptionRatio;
        [SerializeField, Range(3, 5)] float slope;
        [SerializeField, Range(0, 1)] float ffa;
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
            Shader.SetGlobalVector(ShaderProperty.Extinction, extinction);
            Shader.SetGlobalVector(ShaderProperty.AbsorptionRatio, absorptionRatio);
            Shader.SetGlobalFloat(ShaderProperty.Slope, slope);
            Shader.SetGlobalFloat(ShaderProperty.FFa, ffa);
            Shader.SetGlobalFloat(ShaderProperty.InScatteringPower, inScatteringPower);
        }
    }
}
