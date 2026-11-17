{{/* Common sync policy for every child Application */}}
{{- define "lab.syncPolicy" -}}
automated:
  prune: true
  selfHeal: true
syncOptions:
  - CreateNamespace=true
  # Server-side apply: needed for huge CRDs (Prometheus operator, Karpenter,
  # Kyverno) that exceed the 256KB last-applied-configuration annotation.
  - ServerSideApply=true
retry:
  limit: 10
  backoff:
    duration: 15s
    factor: 2
    maxDuration: 5m
{{- end -}}

{{- define "lab.destination" -}}
server: https://kubernetes.default.svc
namespace: {{ . }}
{{- end -}}
