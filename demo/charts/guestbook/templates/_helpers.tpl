{{/* Resolve image reference: prefer digest if set, else repository:tag. */}}
{{- define "guestbook.image" -}}
{{- if .Values.image.digest -}}
{{ .Values.image.repository }}@{{ .Values.image.digest }}
{{- else -}}
{{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- end -}}
{{- end -}}

{{- define "guestbook.labels" -}}
app.kubernetes.io/name: guestbook
{{- end -}}
