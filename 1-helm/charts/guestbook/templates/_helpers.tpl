{{/* Resolve image reference: prefer imageDigest (flat top-level, set by
     Kargo) if present, else fall back to nested image.repository:tag. */}}
{{- define "guestbook.image" -}}
{{- if .Values.imageDigest -}}
{{ .Values.image.repository }}@{{ .Values.imageDigest }}
{{- else -}}
{{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- end -}}
{{- end -}}

{{/* Common labels. */}}
{{- define "guestbook.labels" -}}
app.kubernetes.io/name: guestbook
app.kubernetes.io/part-of: business
{{- end -}}
