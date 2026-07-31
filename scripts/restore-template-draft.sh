#!/usr/bin/env bash
set -euo pipefail

template_id="${1:?Usage: ./scripts/restore-template-draft.sh TEMPLATE_ID WORKSPACE_ID}"
workspace_id="${2:?Usage: ./scripts/restore-template-draft.sh TEMPLATE_ID WORKSPACE_ID}"
template_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
railway_config_path="${RAILWAY_CONFIG_PATH:-${HOME}/.railway/config.json}"
railway_access_token="$(jq -r '.user.accessToken' "${railway_config_path}")"
graph_payload="$(cd "${template_root}" && ./node_modules/.bin/railway-iac-ts .railway/railway.ts)"
draft_payload="$(railway api 'query Draft($id: String!) { template(id: $id) { serializedConfig } }' --var "id=${template_id}" --compact)"

variables="$({
  jq -nc \
    --argjson draft "${draft_payload}" --argjson graph "${graph_payload}" \
    --slurpfile defaults "${template_root}/template-defaults.json" \
    --slurpfile descriptions "${template_root}/template-descriptions.json" \
    --slurpfile volumes "${template_root}/template-volumes.json" \
    --slurpfile networking "${template_root}/template-networking.json" \
    --arg id "${template_id}" --arg workspaceId "${workspace_id}" '
      $draft.data.template.serializedConfig as $config |
      ($graph.graph.resources | map(select(.type == "service")) | map({key:.name,value:.}) | from_entries) as $desired |
      reduce ($config.services | to_entries[]) as $service (
        $config;
        if $desired[$service.value.name].source.type == "image" then
          .services[$service.key].source.image = $desired[$service.value.name].source.image |
          del(.services[$service.key].source.repo, .services[$service.key].source.branch, .services[$service.key].source.rootDirectory, .services[$service.key].build)
        else
          del(.services[$service.key].source.image) |
          .services[$service.key].source.repo = $desired[$service.value.name].source.repo |
          .services[$service.key].source.branch = $desired[$service.value.name].source.branch |
          .services[$service.key].source.rootDirectory = $desired[$service.value.name].source.rootDirectory |
          .services[$service.key].build = ((.services[$service.key].build // {}) + $desired[$service.value.name].build)
        end |
        .services[$service.key].deploy.startCommand = ($desired[$service.value.name].deploy.startCommand // null) |
        .services[$service.key].deploy.preDeployCommand = ($desired[$service.value.name].deploy.preDeployCommand // null) |
        .services[$service.key].deploy.healthcheckPath = ($desired[$service.value.name].deploy.healthcheckPath // null) |
        .services[$service.key].deploy.healthcheckTimeout = ($desired[$service.value.name].deploy.healthcheckTimeout // null) |
        reduce (($defaults[0][$service.value.name] // {}) | to_entries[]) as $variable (
          .;
          .services[$service.key].variables[$variable.key] = ((.services[$service.key].variables[$variable.key] // {}) + {
            defaultValue:$variable.value,
            isOptional:false,
            description:($descriptions[0][$service.value.name][$variable.key] // "")
          })
        ) |
        if $volumes[0][$service.value.name] != null then
          reduce (.services[$service.key].volumeMounts | keys[]) as $mount (
            .;
            .services[$service.key].volumeMounts[$mount].mountPath = $volumes[0][$service.value.name].mountPath |
            .services[$service.key].volumeMounts[$mount].sizeMB = $volumes[0][$service.value.name].sizeMB
          )
        else . end |
        if $networking[0][$service.value.name].publicPort != null then
          .services[$service.key].networking.serviceDomains["<hasDomain>"].port = $networking[0][$service.value.name].publicPort
        else . end
      ) |
      {id:$id,input:{name:"dbt + Metabase analytics",workspaceId:$workspaceId,serializedConfig:.}}
    '
})"

request="$(jq -nc --argjson variables "${variables}" --arg query '
  mutation UpdateDraft($id: String!, $input: TemplateUpsertConfigInput!) {
    templateUpsertConfig(id: $id, input: $input) { id code }
  }' '{query:$query,variables:$variables}')"
response="$(curl --compressed --fail --silent --show-error https://backboard.railway.com/graphql/internal \
  --header "Authorization: Bearer ${railway_access_token}" --header "Content-Type: application/json" --data-binary "${request}")"
jq -e '.data.templateUpsertConfig.id != null and ((.errors // []) | length == 0)' <<<"${response}" >/dev/null

settings_request="$(jq -nc \
  --arg id "${template_id}" --arg workspaceId "${workspace_id}" --arg query '
    mutation RenameDraft($id: String!, $input: TemplateUpsertSettingsInput!) {
      templateUpsertSettings(id: $id, input: $input) { id name }
    }' \
  '{query:$query,variables:{id:$id,input:{name:"dbt + Metabase analytics",workspaceId:$workspaceId}}}')"
settings_response="$(curl --compressed --fail --silent --show-error https://backboard.railway.com/graphql/internal \
  --header "Authorization: Bearer ${railway_access_token}" --header "Content-Type: application/json" --data-binary "${settings_request}")"
jq -e '.data.templateUpsertSettings.name == "dbt + Metabase analytics" and ((.errors // []) | length == 0)' <<<"${settings_response}" >/dev/null
echo "Restored dbt + Metabase template ${template_id} sources, commands, variables, volumes, and networking."
