{{/* Resolve image reference: prefer digest if set, else repository:tag. */}}
{{- define "guestbook.image" -}}
{{- if .Values.image.digest -}}
{{ .Values.image.repository }}@{{ .Values.image.digest }}
{{- else -}}
{{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- end -}}
{{- end -}}

{{/* Common labels. */}}
{{- define "guestbook.labels" -}}
app.kubernetes.io/name: guestbook
app.kubernetes.io/part-of: business
{{- end -}}
