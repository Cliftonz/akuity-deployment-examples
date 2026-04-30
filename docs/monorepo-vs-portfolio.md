# Monorepo vs portfolio: the GitOps repo-shape decision

One of the user's bonus considerations is when each repo shape is correct. The headline is that **the right answer changes with org maturity, and the trigger to switch is operational, not philosophical.** This page lives in `docs/` because it spans every tier, but the actual transition happens at tier 1 → tier 2.

## The two shapes

**Monorepo.** One git repo carries every app's chart, every platform addon, every Kargo Stage. One `argocd/` directory drives an Argo CD instance. One platform team owns CODEOWNERS for the whole thing.

**Portfolio.** Each business app lives in its own repo (`github.com/<org>/<app>-config`). A separate platform repo carries shared component workloads (`github.com/<org>/platform`). A separate env-repo per cluster carries the rendered output (`github.com/<org>/env-prod`). Argo CD ApplicationSets stitch the repos back together at apply time.

The Akuity Kargo quickstart ships monorepo-shaped. Most production deployments at customers past 50 engineers are portfolio-shaped.

## When each shape is correct

| Org shape | Repo shape | Why |
|---|---|---|
| 5–20 engineers, no platform team (tier 0) | Monorepo | Splitting repos would slow down the one-person SRE without solving any problem they have |
| 50–200 engineers, small platform team, multiple product teams (tier 1) | Portfolio (with the platform repo as the bridge) | Teams need to ship without waiting for platform team review of their app config |
| 500+ engineers, real platform org (tier 3+) | Portfolio with bidirectional contracts (claims live in app repos, XRDs/Compositions live in platform repo) | Platform team owns the abstraction; app teams own the consumption |

## The trigger to switch

You move from monorepo to portfolio when **the platform team becomes a review bottleneck on app-team config changes.** Concretely: when a team submits a PR that touches only their chart's `values-prod.yaml` and the PR sits for 24 hours waiting for platform-team review because CODEOWNERS routes everything in the monorepo to them.

Counter-trigger: don't switch early. Splitting repos before there's distinct ownership is overhead without payoff. Three signals you're not ready to split:
- One person can review every PR across all repos in under 30 minutes a day.
- No team has filed an issue that says "I'm waiting on you to review my chart change."
- The monorepo's CODEOWNERS file has one or two lines.

## How Kargo and Argo CD survive the transition

**Kargo Stages can reference cross-repo sources.** A Stage's `requestedFreight` and `promotionTemplate` reference repos by URL; nothing requires them to be in the same repo as the Stage definition itself. The promotion machinery doesn't care which repo the bytes came from.

**Argo CD ApplicationSets stitch portfolios back together.** A list / git / cluster generator reads from one repo (the platform repo) but produces Applications that pull from many (per-app repos plus the env repo). The hub of the wagon-wheel is the ApplicationSet config; the spokes are the per-app repos.

**Rendered manifests live in the env repo regardless of shape.** Whether the chart sources are in one repo or twenty, Kargo always commits the hydrated YAML to a dedicated env repo (or env branch). That's the constant. See [`rendered-manifests-pattern.md`](rendered-manifests-pattern.md).

## What this repo actually demonstrates

This repo is **monorepo-shaped on purpose** — five tier folders + framework + docs in one tree makes the maturity ladder readable in one clone. A real tier-2 customer's repo layout would look closer to:

```
github.com/<org>/platform           # XRDs, Compositions, component workloads, AppSets
github.com/<org>/guestbook-config   # one chart + per-env values, one Kargo project
github.com/<org>/orders-config      # …
github.com/<org>/env-prod           # rendered manifests, per-env branch
```

The `1-helm/` tier README mentions "the repo layout goes portfolio-style" but the demo doesn't physically split — that would force a reviewer to clone five repos to see one ladder. The narrative carries the shape.

## Recommendation per tier

- **Tier 0:** monorepo. Don't even discuss the alternative until tier 1 trigger fires.
- **Tier 1:** portfolio for app config; monorepo for platform team artifacts. The split costs less than nothing because two-thirds of the apps are tier-zero-shaped (one chart, one team, one env path).
- **Tier 2:** same shape as tier 1; the wild-west TF state lives wherever the team picked it (which is the problem the next tier solves).
- **Tier 3:** portfolio with claim/XRD bidirectional contracts. App repos hold claims; platform repo holds XRDs+Compositions. Crossplane composes against the platform repo's API regardless of which app repo the claim came from.
- **Tier 4:** same as tier 3, with one env repo per region.

## References

- This decision shows up in real customer onboarding conversations roughly two-thirds of the way through tier-1 adoption. The trigger conversation is the SE conversation worth having.
- See [`tier-1-helm.md`](tier-1-helm.md) for the customer profile that lives at the transition point.
