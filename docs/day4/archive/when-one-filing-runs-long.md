---
layout: default
title: "When One Filing Runs Long (archived)"
parent: "Day 4 — Parallelization & GPUs"
nav_exclude: true
search_exclude: true
permalink: /day4/archive/when-one-filing-runs-long/
---

# When One Filing Runs Long (archived)

**Archived — not part of the course flow.** Cut from
[Parallelization Basics](../parallelization/) on 2026-08-01 as orthogonal to that
page's argument. Kept because it is a good basis for a load-imbalance exercise —
see `TODO.md`.

---
## When One Filing Runs Long

So far every filing took the same 5 seconds. Real filings aren't so uniform — a dense filing with many transactions can take two or three times as long as a simple one. Take the same eight filings, but let **filing 3 run 3× long** — mid-row, and in the middle of job 1's chunk in the two-job split below. Now the two approaches behave differently.

**Within one job**, the cores share the batch dynamically — each grabs the next free filing the moment it's done. The long filing simply gets absorbed: one core settles into it while the other sweeps up the remaining short filings, and both finish together at **t = 5**:

<svg viewBox="0 0 600 178" role="img" aria-labelledby="lf1-title lf1-desc" xmlns="http://www.w3.org/2000/svg" style="display:block;width:100%;max-width:598px;height:auto;margin:1.5rem auto" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif">
  <title id="lf1-title">One job, two cores, one long filing in the middle: the cores rebalance</title>
  <desc id="lf1-desc">A single SLURM job box holds two CPUs and eight filings; the third filing takes three times as long as the others. One CPU settles into the long filing while the other sweeps up the remaining short filings, so both stay busy and finish together at time five.</desc>
  <rect x="6" y="6" width="588" height="136" rx="12" fill="#f7f9fd" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="22" y="25" font-size="12" font-weight="700" fill="#8a93a3">Job</text>
  <text x="300" y="30" font-size="11" font-weight="600" fill="#009E73" text-anchor="middle" opacity="0">all eight done at t = 5<animate attributeName="opacity" values="0;0;1;1;0" keyTimes="0;0.66;0.70;0.88;1" dur="14s" repeatCount="indefinite" calcMode="linear"/></text>
  <rect x="22"  y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="52"  y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 1</text>
  <rect x="92"  y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="122" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 2</text>
  <rect x="162" y="86" width="60" height="48" rx="9" fill="#fdf1e0" stroke="#e6cfa8" stroke-width="1.5"/>
  <text x="192" y="104" font-size="11" fill="#2c3e50" text-anchor="middle">filing 3</text>
  <text x="192" y="120" font-size="9" font-weight="600" fill="#b26a00" text-anchor="middle">long ×3</text>
  <rect x="232" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="262" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 4</text>
  <rect x="302" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="332" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 5</text>
  <rect x="372" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="402" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 6</text>
  <rect x="442" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="472" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 7</text>
  <rect x="512" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="542" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 8</text>
  <g>
    <path d="M45,75 L59,75 L52,86 Z" fill="#0072B2"/>
    <circle cx="52" cy="58" r="18" fill="#0072B2"><animate attributeName="r" values="18;20;18" dur="1s" repeatCount="indefinite"/></circle>
    <text x="52" y="61" font-size="8.5" font-weight="700" fill="#ffffff" text-anchor="middle">CPU 1</text>
    <animateTransform attributeName="transform" type="translate" values="0,0;0,0;140,0;140,0;420,0;420,0;0,0" keyTimes="0;0.115;0.13;0.505;0.52;0.88;1" dur="14s" repeatCount="indefinite" calcMode="linear"/>
  </g>
  <g>
    <path d="M115,75 L129,75 L122,86 Z" fill="#E69F00"/>
    <circle cx="122" cy="58" r="18" fill="#E69F00"><animate attributeName="r" values="18;20;18" dur="1s" repeatCount="indefinite"/></circle>
    <text x="122" y="61" font-size="8.5" font-weight="700" fill="#ffffff" text-anchor="middle">CPU 2</text>
    <animateTransform attributeName="transform" type="translate" values="0,0;0,0;140,0;140,0;210,0;210,0;280,0;280,0;420,0;420,0;0,0" keyTimes="0;0.115;0.13;0.245;0.26;0.375;0.39;0.505;0.52;0.88;1" dur="14s" repeatCount="indefinite" calcMode="linear"/>
  </g>
  <text x="300" y="164" font-size="12.5" fill="#6a7280" text-anchor="middle">CPU 1 settles into the long filing; CPU 2 sweeps up the rest — everything is done at t = 5.</text>
</svg>

That's the strength of a shared pool of work: as long as anything is left to do, no core waits.

**Across two jobs**, the filings were split into fixed chunks before anything ran — job 1 gets filings 1–4, long one included; job 2 gets 5–8. The chunks can't help each other: job 2 clears its short filings by **t = 4**, finishes, and releases its core back to the cluster, while job 1 grinds on until **t = 6**. The batch is done only when the slowest chunk is — this is **load imbalance**, and fixed chunks have no way to rebalance it:

<svg viewBox="0 0 600 300" role="img" aria-labelledby="lf2-title lf2-desc" xmlns="http://www.w3.org/2000/svg" style="display:block;width:100%;max-width:598px;height:auto;margin:1.5rem auto" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif">
  <title id="lf2-title">Two jobs, one core each, the long filing in job 1's chunk: chunks can't rebalance</title>
  <desc id="lf2-desc">Two stacked SLURM job boxes, each with one CPU and four filings. The long third filing sits in the middle of the first job's chunk: job 1 works until time six, while job 2 clears its four short filings by time four, completes, and releases its core. The whole batch waits on the slowest chunk.</desc>
  <rect x="6" y="6" width="588" height="124" rx="12" fill="#f7f9fd" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="22" y="24" font-size="12" font-weight="700" fill="#8a93a3">Job 1</text>
  <rect x="40"  y="80" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="75"  y="106" font-size="12" fill="#2c3e50" text-anchor="middle">filing 1</text>
  <rect x="190" y="80" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="225" y="106" font-size="12" fill="#2c3e50" text-anchor="middle">filing 2</text>
  <rect x="340" y="80" width="70" height="44" rx="9" fill="#fdf1e0" stroke="#e6cfa8" stroke-width="1.5"/>
  <text x="375" y="100" font-size="12" fill="#2c3e50" text-anchor="middle">filing 3</text>
  <text x="375" y="116" font-size="9" font-weight="600" fill="#b26a00" text-anchor="middle">long ×3</text>
  <rect x="490" y="80" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="525" y="106" font-size="12" fill="#2c3e50" text-anchor="middle">filing 4</text>
  <text x="240" y="58" font-size="11" font-weight="600" fill="#6a7280" text-anchor="middle" opacity="0">done at t = 6<animate attributeName="opacity" values="0;0;1;1;0" keyTimes="0;0.78;0.82;0.88;1" dur="14s" repeatCount="indefinite" calcMode="linear"/></text>
  <g>
    <path d="M68,70 L82,70 L75,80 Z" fill="#0072B2"/>
    <circle cx="75" cy="54" r="16" fill="#0072B2"><animate attributeName="r" values="16;18;16" dur="1s" repeatCount="indefinite"/></circle>
    <text x="75" y="57" font-size="8.5" font-weight="700" fill="#ffffff" text-anchor="middle">CPU 1</text>
    <animateTransform attributeName="transform" type="translate" values="0,0;0,0;150,0;150,0;300,0;300,0;450,0;450,0;0,0" keyTimes="0;0.115;0.13;0.245;0.26;0.635;0.65;0.88;1" dur="14s" repeatCount="indefinite" calcMode="linear"/>
  </g>
  <rect x="6" y="146" width="588" height="124" rx="12" fill="#f7f9fd" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="22" y="164" font-size="12" font-weight="700" fill="#8a93a3">Job 2</text>
  <rect x="40"  y="220" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="75"  y="246" font-size="12" fill="#2c3e50" text-anchor="middle">filing 5</text>
  <rect x="190" y="220" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="225" y="246" font-size="12" fill="#2c3e50" text-anchor="middle">filing 6</text>
  <rect x="340" y="220" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="375" y="246" font-size="12" fill="#2c3e50" text-anchor="middle">filing 7</text>
  <rect x="490" y="220" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="525" y="246" font-size="12" fill="#2c3e50" text-anchor="middle">filing 8</text>
  <text x="240" y="198" font-size="11" font-weight="600" fill="#009E73" text-anchor="middle" opacity="0">job complete at t = 4 — core released ✓<animate attributeName="opacity" values="0;0;1;1;0" keyTimes="0;0.54;0.58;0.88;1" dur="14s" repeatCount="indefinite" calcMode="linear"/></text>
  <g>
    <path d="M68,210 L82,210 L75,220 Z" fill="#E69F00"/>
    <circle cx="75" cy="194" r="16" fill="#E69F00"><animate attributeName="r" values="16;18;16" dur="1s" repeatCount="indefinite"/></circle>
    <text x="75" y="197" font-size="8.5" font-weight="700" fill="#ffffff" text-anchor="middle">CPU 2</text>
    <animate attributeName="opacity" values="1;1;0.15;0.15;1" keyTimes="0;0.52;0.56;0.9;1" dur="14s" repeatCount="indefinite" calcMode="linear"/>
    <animateTransform attributeName="transform" type="translate" values="0,0;0,0;150,0;150,0;300,0;300,0;450,0;450,0;450,0;0,0" keyTimes="0;0.115;0.13;0.245;0.26;0.375;0.39;0.505;0.88;1" dur="14s" repeatCount="indefinite" calcMode="linear"/>
  </g>
  <text x="300" y="290" font-size="12.5" fill="#6a7280" text-anchor="middle">Fixed chunks can't share the load: job 1 runs to t = 6 while job 2 finishes at t = 4 and releases its core.</text>
</svg>

Same filings, same cores — different totals. The shared pool finishes at **t = 5**; the fixed chunks finish at **t = 6**, because job 2 can't help with a filing that isn't in its chunk. What the two-job version buys instead is release: job 2's core goes back to the cluster at t = 4, while the one-job version holds both cores until the whole batch ends.

{: .tip }
> **If you can order the work, run the longest tasks first.** Load imbalance bites hardest when a long task starts *late* — the other cores finish and sit idle waiting for it. Start the longest tasks first and the short ones backfill around them, so the cores finish close together. This is the "longest processing time first" rule, and it's provably within a third of the best-possible finish time. It does need a rough sense of which tasks are long, but a cheap proxy often works — e.g. sort the filings by file size (bigger ≈ slower) and process the biggest first.
