{{/*
Wiederverwendbare Template-Funktionen.

Die komponentenbezogenen Helper erwarten ein dict mit zwei Schluesseln:
  ctx       - der Root-Kontext ($)
  component - "backend" | "frontend" | "postgres"
Aufruf z.B.:
  {{- include "user-mgmt.componentLabels" (dict "ctx" $ "component" "backend") | nindent 4 }}
*/}}

{{/* Basisname des Charts, per nameOverride ueberschreibbar. */}}
{{- define "user-mgmt.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Voll qualifizierter Release-Name. Enthaelt der Release-Name den Chart-Namen
bereits, wird er nicht doppelt vorangestellt.
*/}}
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

{{/*
Ressourcenname einer Komponente, z.B. "user-mgmt-backend".
Wird sowohl fuer Deployment als auch fuer den zugehoerigen Service verwendet,
damit Service-DNS und Workload garantiert zusammenpassen.
*/}}
{{- define "user-mgmt.componentName" -}}
{{- printf "%s-%s" (include "user-mgmt.fullname" .ctx) .component | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector-Labels einer Komponente. Muessen ueber die Lebensdauer eines
Deployments stabil bleiben - deshalb bewusst ohne Version und Chart.
*/}}
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

{{/*
Vollstaendige Image-Referenz "registry/repository/name:tag".
"registry" und "repository" fallen auf die globalen Werte zurueck, wenn die
Komponente sie nicht selbst setzt - so liegen Backend und Frontend in GHCR,
PostgreSQL aber in Docker Hub.
*/}}
{{- define "user-mgmt.image" -}}
{{- $global := .ctx.Values.image -}}
{{- $img := .image -}}
{{- $registry := default $global.registry $img.registry -}}
{{- $repository := default $global.repository $img.repository -}}
{{- printf "%s/%s/%s:%s" $registry $repository $img.name (toString $img.tag) -}}
{{- end }}

{{/*
JDBC-URL der Datenbank. Baut den Hostnamen aus dem getemplateten Servicenamen,
damit er nicht in der ConfigMap hartcodiert werden muss und auch bei
abweichendem Release-Namen korrekt bleibt.
*/}}
{{- define "user-mgmt.datasourceUrl" -}}
{{- $svc := include "user-mgmt.componentName" (dict "ctx" . "component" "postgres") -}}
{{- printf "jdbc:postgresql://%s:%v/%s" $svc (.Values.postgres.service.port | int) .Values.config.postgresDb -}}
{{- end }}

{{/* Namen von ConfigMap und Secret, an mehreren Stellen referenziert. */}}
{{- define "user-mgmt.configMapName" -}}
{{- printf "%s-config" (include "user-mgmt.fullname" .) }}
{{- end }}

{{- define "user-mgmt.secretName" -}}
{{- printf "%s-secret" (include "user-mgmt.fullname" .) }}
{{- end }}
