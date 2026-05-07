{{/* Resolve image reference. */}}
{{- define "guestbook.image" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- end -}}

{{/* Common labels. */}}
{{- define "guestbook.labels" -}}
app.kubernetes.io/name: guestbook
app.kubernetes.io/part-of: demo
{{- end -}}
