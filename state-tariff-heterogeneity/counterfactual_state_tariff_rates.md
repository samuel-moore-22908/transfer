# Counterfactual State Effective Tariff Rates

Every state has its own effective tariff rate because it imports its own mix of products from its own mix of trading partners. This note builds two counterfactual rates for each state:

1. **Partner-only:** the state imports the national product mix, so only its trading partners vary.
2. **Product-only:** the state uses the national partner mix, so only the products it imports vary.

Both use the same recipe. Take one margin of the state's joint distribution and pair it with the national conditional distribution for the other dimension. That gives a counterfactual joint matrix, which you then weight against the tariff matrix.

---

## Notation

Products are indexed by $i = 1,\dots,I$ (rows) and partners by $j = 1,\dots,J$ (columns). $\mathbf{1}_I$ and $\mathbf{1}_J$ are vectors of ones, $\circ$ is the elementwise (Hadamard) product, $\oslash$ is elementwise division, and $\text{diag}(v)$ is a diagonal matrix with $v$ on the diagonal.

| Object | Dim | Definition | Property |
|---|---|---|---|
| $S^s$ | $I\times J$ | State $s$ joint: $S^s_{ij} = M^s_{ij}/M^s$ | $\mathbf{1}_I' S^s \mathbf{1}_J = 1$ |
| $N$ | $I\times J$ | National joint: $N_{ij} = M_{ij}/M$ | $\mathbf{1}_I' N \mathbf{1}_J = 1$ |
| $A$ | $I\times J$ | National product given partner: $A_{ij} = N_{ij}/\sum_i N_{ij}$ | columns sum to 1: $\mathbf{1}_I'A = \mathbf{1}_J'$ |
| $B$ | $I\times J$ | National partner given product: $B_{ij} = N_{ij}/\sum_j N_{ij}$ | rows sum to 1: $B\mathbf{1}_J = \mathbf{1}_I$ |
| $T$ | $I\times J$ | Tariff rate on product $i$ from partner $j$ | — |

If your tariff matrix holds duties rather than rates, first convert it to rates: $T = D \oslash M$. Set $T_{ij}=0$ wherever national imports are zero. Those cells have zero weight everywhere, so the choice doesn't affect any result.

---

## Step 0: Actual effective rates (your benchmark)

$$
\tau^s = \mathbf{1}_I'(S^s \circ T)\mathbf{1}_J = \text{tr}(S^{s\prime} T),
\qquad
\tau^N = \mathbf{1}_I'(N \circ T)\mathbf{1}_J
$$

---

## Step 1: Get the state marginals from the state joint matrix

$$
p^s = S^{s\prime}\mathbf{1}_I \quad (J\times 1,\ \text{state partner shares})
$$

$$
q^s = S^s\mathbf{1}_J \quad (I\times 1,\ \text{state product shares})
$$

---

## Step 2: Build the counterfactual joint matrices

### Counterfactual 1: national product mix, the state's own partners

Each partner's share of the state's imports is kept, but the goods bought from each partner follow the national basket from that partner:

$$
X^{s,1} = A\,\text{diag}(p^s),
\qquad
X^{s,1}_{ij} = A_{ij}\,p^s_j
$$

### Counterfactual 2: national partner mix, the state's own products

Each product's share of the state's imports is kept, but each product is sourced across partners the way the nation sources it:

$$
X^{s,2} = \text{diag}(q^s)\,B,
\qquad
X^{s,2}_{ij} = q^s_i\,B_{ij}
$$

### Check that both are valid joint distributions

- CF1: $\mathbf{1}_I' A\,\text{diag}(p^s)\mathbf{1}_J = \mathbf{1}_J' p^s = 1$
- CF2: $\mathbf{1}_I'\text{diag}(q^s)B\mathbf{1}_J = q^{s\prime}\mathbf{1}_I = 1$

---

## Step 3: Apply the tariff matrix

$$
\tau^{s,1} = \mathbf{1}_I'(X^{s,1}\circ T)\mathbf{1}_J,
\qquad
\tau^{s,2} = \mathbf{1}_I'(X^{s,2}\circ T)\mathbf{1}_J
$$

---

## Step 4: Simplify to marginal × national average tariff

Diagonal scaling commutes with the Hadamard product:

- $(X\,\text{diag}(b))\circ T = (X\circ T)\,\text{diag}(b)$
- $(\text{diag}(a)\,X)\circ T = \text{diag}(a)\,(X\circ T)$

Applying this gives:

$$
\tau^{s,1}
= \mathbf{1}_I'(A\circ T)\,\text{diag}(p^s)\mathbf{1}_J
= \underbrace{\mathbf{1}_I'(A\circ T)}_{t_J'}\,p^s
= t_J'\,p^s
$$

$$
\tau^{s,2}
= \mathbf{1}_I'\,\text{diag}(q^s)(B\circ T)\mathbf{1}_J
= q^{s\prime}\underbrace{(B\circ T)\mathbf{1}_J}_{t_P}
= q^{s\prime}\,t_P
$$

where:

- $t_J = (A\circ T)'\mathbf{1}_I$ ($J\times 1$) is the national trade-weighted average tariff on each partner.
- $t_P = (B\circ T)\mathbf{1}_J$ ($I\times 1$) is the national trade-weighted average tariff on each product.

You only need to compute these two vectors once.

---

## Step 5: All states at once

Stack the marginals as $P = [p^1 \cdots p^S]$ ($J\times S$) and $Q = [q^1 \cdots q^S]$ ($I\times S$). Then:

$$
\boldsymbol{\tau}^{1} = P'\,t_J,
\qquad
\boldsymbol{\tau}^{2} = Q'\,t_P
\qquad (S\times 1)
$$

### Implementation (numpy)

With arrays shaped `(n_states, I, J)` for the state joints and `(I, J)` for the national pieces:

```python
p = S.sum(axis=1)                  # (n_states, J) partner marginals
q = S.sum(axis=2)                  # (n_states, I) product marginals
t_J = (A * T).sum(axis=0)          # (J,) national avg tariff by partner
t_P = (B * T).sum(axis=1)          # (I,) national avg tariff by product
tau_actual = (S * T).sum(axis=(1, 2))
tau_cf1 = p @ t_J                  # national product mix, state partners
tau_cf2 = q @ t_P                  # national partner mix, state products
```

---

## Sanity checks

1. **A state with the national margin gets the national rate.** If $p^s = N'\mathbf{1}_I$, then $A\,\text{diag}(p^s) = N$, so $\tau^{s,1} = \tau^N$. The same holds for CF2 when $q^s = N\mathbf{1}_J$.

2. **Weighted averages recover the national rate.** Let $w_s = M^s/M$ be each state's share of national imports. Then $\sum_s w_s p^s = N'\mathbf{1}_I$ and $\sum_s w_s q^s = N\mathbf{1}_J$. So the import-weighted averages of $\tau^{s,1}$, $\tau^{s,2}$ and $\tau^s$ should all equal $\tau^N$ exactly.

3. **Decomposition.** Each state's gap to the national rate splits into a partner effect, a product effect and an interaction:

$$
\tau^s - \tau^N = (\tau^{s,1}-\tau^N) + (\tau^{s,2}-\tau^N) + R^s
$$

The interaction $R^s$ is the leftover. It is large when a state's unusual partners and unusual products are tied together, for example importing electronics specifically from China.

---

## Caveat: what "national mix" holds fixed

CF1 holds the product mix *within each partner* at the national pattern, not the state's overall product margin. The implied product shares are $A\,p^s$, which differ from the national product shares whenever $p^s$ differs from the national partner shares. CF2 has the same property for partners. This is the standard way to split the gap and the only one the listed pieces support directly.

If you instead want the overall product margin fixed exactly at national, you need the state's own partner-given-product conditional, which you can derive from the state joint:

$$
B^s = \text{diag}(q^s)^{-1}S^s,
\qquad
\tilde{X}^{s,1} = \text{diag}(N\mathbf{1}_J)\,B^s
$$

This answers a slightly different question, so the two versions won't give the same numbers.
