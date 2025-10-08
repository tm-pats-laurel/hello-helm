# Troubleshooting Notes

## Issue #1: Template Syntax in values.yaml

### Problem

When deploying with `helm install`, got the following error:

```
Error: INSTALLATION FAILED: 1 error occurred:
* Deployment.apps "my-backend" is invalid: 
  [spec.template.spec.containers[0].env[2].valueFrom.secretKeyRef.name: 
   Invalid value: "{{ .Release.Name }}-postgres-secret": 
   a lowercase RFC 1123 subdomain must consist of lower case alphanumeric characters...]
```

### Root Cause

The `values.yaml` file contained Helm template syntax like `{{ .Release.Name }}`:

```yaml
# ❌ WRONG - Template syntax in values.yaml
env:
  - name: DB_HOST
    value: "{{ .Release.Name }}-postgres"
  - name: DB_NAME
    valueFrom:
      secretKeyRef:
        name: "{{ .Release.Name }}-postgres-secret"
        key: database
```

**The issue:** Template syntax (`{{ }}`) only works in files inside the `templates/` directory, not in `values.yaml`. Values files contain plain YAML data, not templates.

When Helm tried to deploy, it passed the literal string `"{{ .Release.Name }}-postgres-secret"` to Kubernetes, which rejected it because it's not a valid DNS name.

### Solution

Move the template logic to `templates/deployment.yaml` where Helm template processing actually happens:

**values.yaml** (simplified):
```yaml
# ✅ CORRECT - Plain values only
env:
  PYTHONUNBUFFERED: "1"
```

**templates/deployment.yaml** (template logic):
```yaml
# ✅ CORRECT - Template syntax in templates directory
env:
  {{- range $key, $value := .Values.env }}
  - name: {{ $key }}
    value: {{ $value | quote }}
  {{- end }}
  {{- if .Values.postgres.enabled }}
  - name: DB_HOST
    value: {{ printf "%s-postgres" .Release.Name | quote }}
  - name: DB_NAME
    valueFrom:
      secretKeyRef:
        name: {{ printf "%s-postgres-secret" .Release.Name }}
        key: database
  # ... etc
  {{- end }}
```

### Key Lessons

1. **values.yaml is NOT a template** - It contains plain YAML data
2. **Templates go in templates/** - Only files in `templates/` are processed as templates
3. **Use `printf` or string interpolation in templates** - Construct dynamic names in template files
4. **Test with `helm template`** - Render templates locally to catch issues before deploying

### How to Verify

```bash
# Render templates without installing
helm template my-backend . | grep -A 10 "env:"

# Should show properly rendered environment variables like:
#   - name: DB_HOST
#     value: "my-backend-postgres"
#   - name: DB_NAME
#     valueFrom:
#       secretKeyRef:
#         name: my-backend-postgres-secret
```

## Testing Checklist

After fixing the issue, verify:

- [x] Helm install succeeds without errors
- [x] Pods start successfully (both backend and postgres)
- [x] Init container completes (waits for postgres)
- [x] Backend container is running
- [x] Health checks pass (`/health` returns 200)
- [x] Database connection works (can create items)
- [x] Data persists in PostgreSQL

## Verification Commands

```bash
# Check deployment
helm install my-backend .
kubectl get pods -l app.kubernetes.io/instance=my-backend

# Check logs
kubectl logs -l app.kubernetes.io/name=backend

# Test API
kubectl port-forward svc/my-backend 8000:8000
curl http://localhost:8000/health
curl -X POST http://localhost:8000/items \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","description":"Testing!"}'
curl http://localhost:8000/items
```

## Additional Tips

### Debug Template Rendering

```bash
# See all rendered manifests
helm template my-backend . > rendered.yaml
cat rendered.yaml

# Debug with verbose output
helm install my-backend . --dry-run --debug

# Check specific value rendering
helm template my-backend . | grep -B 2 -A 2 "DB_HOST"
```

### Common Template Mistakes

❌ **Using templates in values.yaml**
```yaml
# values.yaml
env:
  - name: DB_HOST
    value: "{{ .Release.Name }}-postgres"  # Won't work!
```

✅ **Using values in templates**
```yaml
# templates/deployment.yaml
env:
  - name: DB_HOST
    value: {{ printf "%s-postgres" .Release.Name | quote }}  # Works!
```

❌ **Forgetting quotes for DNS names**
```yaml
value: {{ .Release.Name }}-postgres  # Missing quotes
```

✅ **Proper quoting**
```yaml
value: {{ printf "%s-postgres" .Release.Name | quote }}  # Correct
```

### Understanding the Template Context

- `.Release.Name` - Name you gave during `helm install`
- `.Release.Namespace` - Kubernetes namespace
- `.Chart.Name` - Chart name from Chart.yaml
- `.Values.*` - Values from values.yaml (and overrides)

### Best Practices

1. **Keep values.yaml simple** - Just configuration data
2. **Put logic in templates** - All conditionals, loops, string building
3. **Use helper functions** - Define reusable templates in `_helpers.tpl`
4. **Test locally first** - Use `helm template` before `helm install`
5. **Document your values** - Add comments explaining what each value does

## Related Documentation

- [Helm Template Guide](https://helm.sh/docs/chart_template_guide/)
- [Go Template Syntax](https://pkg.go.dev/text/template)
- [Sprig Functions](http://masterminds.github.io/sprig/) (used by Helm)
- [Kubernetes DNS Names](https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#dns-subdomain-names)

## Success!

After the fix:
- ✅ Helm chart deploys successfully
- ✅ Backend connects to PostgreSQL
- ✅ API endpoints work correctly
- ✅ Data persists across pod restarts
- ✅ Health checks pass
- ✅ Template rendering works correctly

**Deployment verified on:** Oct 8, 2025

