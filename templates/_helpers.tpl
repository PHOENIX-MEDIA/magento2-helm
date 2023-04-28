{{/*
Expand the name of the chart.
*/}}
{{- define "magento.name" -}}
{{- default .Chart.Name .Values.magento.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "magento.fullname" -}}
{{- if .Values.magento.fullnameOverride }}
{{- .Values.magento.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.magento.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "magento.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
      workload.user.cattle.io/workloadselector: {{ .Values.magento.deploymentlabel }}

*/}}
{{- define "magento.labels" -}}
helm.sh/chart: {{ include "magento.chart" . }}
{{ include "magento.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "magento.selectorLabels" -}}
app.kubernetes.io/name: {{ include "magento.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Container image
*/}}
{{- define "magento.image" -}}
{{- $registryName := .Values.image.registry -}}
{{- $repositoryName := .Values.image.repository -}}
{{- $tag := "" -}}
{{- if .Values.image.tag }}
{{- $tag = printf ":%s" .Values.image.tag -}}
{{- end -}}
{{- if $registryName }}
{{- printf "%s/%s%s" $registryName $repositoryName $tag -}}
{{- else -}}
{{- printf "%s%s" $repositoryName $tag -}}
{{- end -}}
{{- end -}}

{{/*
Return persistent volume claim
*/}}
{{- define "magento.pvcName" -}}
{{- if .Values.persistence.existingClaim }}
{{- print .Values.persistence.existingClaim }}
{{- else if .Values.persistence.name -}}
{{- print .Values.persistence.name }}
{{- else -}}
{{- printf "%s-magento" (include "magento.fullname" .) }}
{{- end -}}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "magento.imagePullSecrets" -}}
  {{- $pullSecrets := list }}

  {{- if .Values.global }}
    {{- range .Values.global.imagePullSecrets -}}
      {{- $pullSecrets = append $pullSecrets . -}}
    {{- end -}}
  {{- end -}}

  {{- if (not (empty $pullSecrets)) }}
imagePullSecrets:
    {{- range $pullSecrets }}
  - name: {{ . }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Return secret name
*/}}
{{- define "magento.secretName" -}}
  {{- if .Values.secrets.externalSecrets.enabled }}
    {{- print "external-secrets-store" }}
  {{- else -}}
    {{- print .Values.secrets.name }}
  {{- end -}}
{{- end -}}
