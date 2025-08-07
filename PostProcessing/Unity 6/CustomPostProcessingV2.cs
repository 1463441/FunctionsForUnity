using System.Collections;
using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Unity.VisualScripting;
using UnityEditor;
using UnityEngine.Rendering.RenderGraphModule;
using CustomDictionary.SerializableDictionary;
using static BlitProfile_Feature.BlitPass;
using UnityEditor.SceneManagement;


public interface IPostProcessData
{
    public Type GetDataType() => this.GetType(); // virtual 없이
}

public abstract class PostProcessingV2 : MonoBehaviour
{
    internal bool isExcute;
    [SerializeField] protected Shader _shader;
    [SerializeField] protected Material _mat;

    protected abstract string _shaderString { get; }

    internal abstract void Render(RenderGraph renderGraph, ContextContainer frameData, ref TextureHandle sourceTexture, ref TextureHandle tempTexture, string m_ProfilerTag);
    protected abstract void Excute(PassData data, ref RasterGraphContext context);

    internal abstract void Initialize(IPostProcessData data);
    internal virtual void GetMaterial(ref Shader shader, ref Material material, byte flag = 0)
    {
        if(flag != 0)
        {
            if((flag & 0b00000001) != 0)    //플래그 설정됨
                shader = _shader;
            
            if((flag & 0b00000010) != 0)
                material = _mat;
            
            return;
        }

        _shader = shader != null ? shader : (_shader ?? Shader.Find(_shaderString));
        shader = _shader;

        _mat = material != null ? material : (_mat ?? new Material(_shader == null ? throw new Exception("Critial Shader Error") : _shader));
        material = _mat;
    }
}

public class CustomPostProcessingV2 : MonoBehaviour
{
    private static object _lock = new object();
    public static CustomPostProcessingV2 global
    {
        get
        {
            if (_instance == null)
            {
                lock (_lock)
                {
                    if(_instance == null)
                    {                  
                        _instance = FindAnyObjectByType<CustomPostProcessingV2>();
                        if(_instance == null)
                        {
                            GameObject go = new GameObject("PostProcessingV2");
                            _instance = go.AddComponent<CustomPostProcessingV2>();
                        }
                    }
                }
            }
            return _instance;
        }
    }
    private static CustomPostProcessingV2 _instance;


    private void Awake()
    {
        if (_instance == null)
        {
            _instance = this;
            DontDestroyOnLoad(this.gameObject);
        }
        else
        {
            Destroy(this);

            return;
        }
        
        for(int i = 0; i < volumes.Count; i++)
        {
            Type type;
            var volume = volumes[i];
            if (volume != null)
            {
                type = volume.GetType();
                components.Add(type, volume);
            }
            else
                continue;

            Shader shader = null; Material material = null;

            volume.GetMaterial(ref shader, ref material, 0b00000011);

            if(material != null)
                materials.Add(type, material);
            if(shader != null)
                shaderCache.Add(type, shader);
        }
    }

    [SerializeField] private List<PostProcessingV2> volumes = new List<PostProcessingV2>();

    private void OnValidate()
    {
        GC.Collect(1, GCCollectionMode.Forced);
        
        Resources.UnloadUnusedAssets();
    }

    [SerializeField] private SerializableDictionary<Type, PostProcessingV2> components = new SerializableDictionary<Type, PostProcessingV2>();
    [SerializeField] private SerializableDictionary<Type, Material> materials = new SerializableDictionary<Type, Material>();
    [SerializeField] private SerializableDictionary<Type, Shader> shaderCache = new SerializableDictionary<Type, Shader>();

    public T Get<T>() where T : PostProcessingV2, new()
    {
        Type componentType = typeof(T);
        return components.ContainsKey(componentType) ? components[componentType] as T : null;
    }
    public bool Add<T>(T component) where T : PostProcessingV2, new()
    {
        Type componentType = typeof(T);
        if (components.ContainsKey(componentType) == true)
            return false;
        components.Add(componentType, component);

        byte flag = 0;
        if (shaderCache.ContainsKey(componentType) == false)
            flag |= 0b00000001;
        if (materials.ContainsKey(componentType) == false)
            flag |= 0b00000010;
        return true;
    }

    public T AddEffect<T>(IPostProcessData initialData = null) where T :  PostProcessingV2, new()
    {
        Type componentType = typeof(T);

        if (components.ContainsKey(componentType))
        {
#if UNITY_EDITOR
            Debug.LogWarning($"Component {componentType.Name} already exists. Returning existing instance.");
#endif
            return components[componentType] as T;
        }
        try
        {
            T t = this.AddComponent<T>();

            Shader shader = null;
            Material material = null;

            if (shaderCache.ContainsKey(componentType) == true)
            {
                shader = shaderCache[componentType];
                if (materials.ContainsKey(componentType) == true)
                {
                    material = materials[componentType];
                }         
            }

            t.GetMaterial(ref shader, ref material);

            if (shader != null && !shaderCache.ContainsKey(componentType))  //널체크 겸 생성된 경우 저장
            {
                shaderCache[componentType] = shader;
            }
            if (material != null && !materials.ContainsKey(componentType))
            {
                materials[componentType] = material;
            }

            if (initialData != null)
                t.Initialize(initialData);


            volumes.Add(t);

            return t;   
        }
        catch
        {
#if UNITY_EDITOR
            Debug.Log(componentType.Name + " : Add Failed");
#endif
            return null;
        }
    }


    public bool Remove<T>() where T : PostProcessingV2, new()
    {
        for (int i = 0; i < volumes.Count; i++)
        {
            if (volumes[i] is T)
            {
                volumes.RemoveAt(i);
                return true;
            }
        }
        return false;
    }


    public bool Render(RenderGraph renderGraph, ContextContainer frameData, ref TextureHandle sourceTexture, ref TextureHandle tempTexture, string m_ProfilerTag)
    {
        if (volumes.Count == 0)
            return false;

        for (int i = 0; i < volumes.Count; i++)
        {
            volumes[i].Render(renderGraph, frameData, ref sourceTexture, ref tempTexture, m_ProfilerTag);
            if(i != volumes.Count - 1)
            {
                TextureHandle temp = sourceTexture;
                sourceTexture = tempTexture;
                tempTexture = temp;
            }
        }
        return true;
    }


}

