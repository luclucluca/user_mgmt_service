{{/* Komponentenbezogene Helper erwarten ein dict {ctx: $, component: "backend|frontend|postgres"}. */}}

{{/* Basisname des Charts, per nameOverride ueberschreibbar. */}}
{{- define "user-mgmt.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Voll qualifizierter Release-Name, ohne Chart-Namen doppelt voranzustellen. */}}
{{- define "user-mgmt.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/* Chart-Name samt Version fuer das Label helm.sh/chart. */}}
{{- define "user-mgmt.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Selector-Labels auf Release-Ebene (ohne Komponente). */}}
{{- define "user-mgmt.selectorLabels" -}}
app.kubernetes.io/name: {{ include "user-mgmt.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Vollstaendige Labels auf Release-Ebene, fuer ConfigMap, Secret, Ingress. */}}
{{- define "user-mgmt.labels" -}}
helm.sh/chart: {{ include "user-mgmt.chart" . }}
{{ include "user-mgmt.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Ressourcenname einer Komponente, z.B. "user-mgmt-backend" (Deployment und Service). */}}
{{- define "user-mgmt.componentName" -}}
{{- printf "%s-%s" (include "user-mgmt.fullname" .ctx) .component | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Selector-Labels muessen ueber die Lebensdauer des Deployments stabil bleiben, daher ohne Version/Chart. */}}
{{- define "user-mgmt.componentSelectorLabels" -}}
app.kubernetes.io/name: {{ include "user-mgmt.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/* Vollstaendige Labels einer Komponente. */}}
{{- define "user-mgmt.componentLabels" -}}
helm.sh/chart: {{ include "user-mgmt.chart" .ctx }}
{{ include "user-mgmt.componentSelectorLabels" . }}
app.kubernetes.io/version: {{ .ctx.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
{{- end }}

{{/* Image-Referenz "registry/repository/name:tag"; registry/repository fallen auf globale Werte zurueck. */}}
{{- define "user-mgmt.image" -}}
{{- $global := .ctx.Values.image -}}
{{- $img := .image -}}
{{- $registry := default $global.registry $img.registry -}}
{{- $repository := default $global.repository $img.repository -}}
{{- printf "%s/%s/%s:%s" $registry $repository $img.name (toString $img.tag) -}}
{{- end }}

{{/* JDBC-URL, Hostname aus dem getemplateten Servicenamen, damit nichts hartcodiert werden muss. */}}
{{- define "user-mgmt.datasourceUrl" -}}
{{- $svc := include "user-mgmt.componentName" (dict "ctx" . "component" "postgres") -}}
{{- printf "jdbc:postgresql://%s:%v/%s" $svc (.Values.postgres.service.port | int) .Values.config.postgresDb -}}
{{- end }}

{{/* Namen von ConfigMap und Secret, an mehreren Stellen referenziert. */}}
{{- define "user-mgmt.configMapName" -}}
{{- printf "%s-config" (include "user-mgmt.fullname" .) }}
{{- end }}

{{/* Name des Secrets; ueber secrets.existingSecret abweichend benennbar, wenn create=false. */}}
{{- define "user-mgmt.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- printf "%s-secret" (include "user-mgmt.fullname" .) -}}
{{- end -}}
{{- end }}
