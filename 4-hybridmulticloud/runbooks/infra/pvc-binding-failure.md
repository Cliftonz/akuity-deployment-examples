# PersistentVolumeClaim stuck Pending

**Severity:** sev2.

**Trigger:** a PVC has been in `Pending` for 300+ seconds.

## Symptoms

- `kubectl get pvc -A` shows status `Pending`.
- A Pod that mounts the PVC is stuck in `Pending` waiting for the volume.
- StorageClass `volumeBindingMode: WaitForFirstConsumer` does not bind even after the Pod is scheduled.

## Diagnosis

```bash
# 1. PVC events.
kubectl -n <ns> describe pvc <pvc> | grep -A20 Events:

# 2. Provisioner status.
kubectl get storageclass <sc> -o jsonpath='{.provisioner}'

# 3. Provisioner pod logs (varies by storage class).
kubectl -n kube-system logs -l app=ebs-csi-controller --tail=50
```

## Most common causes

1. **Storage class doesn't exist.** PVC references `storageClassName: <name>` but no `StorageClass` of that name. → either fix the chart's `storageClassName` value, or apply the missing StorageClass.
2. **Provisioner is down.** EBS CSI / GCE PD / OpenEBS controller pods are not running. → check the controller deployment in kube-system.
3. **Account quota exceeded.** AWS account hit its EBS volume limit; provisioner returns `LimitExceeded`. → request a quota bump or delete unused volumes.
4. **Subnet has no IPs left.** Provisioner can't allocate an ENI for the volume. → free IPs in the subnet or scale up the subnet.

## Remediation

Cause-specific. The recovery path is usually external (cloud quota / provisioner health), not git-side.

If the PVC was created by a Helm chart with a too-aggressive size request:
```bash
kubectl -n <ns> delete pvc <pvc>
# Update values-<env>.yaml to a feasible size.
git checkout main
# Edit charts/<app>/values-<env>.yaml.
git commit && git push
# Kargo re-promotes; new PVC at new size.
```

## Verification

```bash
kubectl -n <ns> get pvc <pvc>
# STATUS column transitions Pending → Bound.
```

## Why this matters at tier 2

Tier 2 is the first tier with stateful infrastructure (Postgres via Terraform). PVC binding is therefore on the on-call surface for the first time. Tier 0 and tier 1 had no PVCs.

## What this looks like at higher tiers

Tier 3's Crossplane Composition includes the PVC dimensioning as part of the XDatabase claim, so a `Pending` PVC there is also a "claim stuck" symptom — see `runbooks/platform/crossplane-claim-stuck-pending.md` at tier 3.
