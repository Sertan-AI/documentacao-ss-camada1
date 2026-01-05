# [Contrato de Dados: Camada 1 → Camada 2](https://www.notion.so/Loop-MVP-Monitoramento-de-Campo-Camada-1-2cab777f46dc8003ae7cc46de86b3d2f)

<div align="center">

**Versão:** V0  
**Status:** ✅ Concluído, aguardando validação  
**Responsável:** Samuel Santos (Camada 1)  
**Consumidores diretos:** Camada 2 XAI / SHAP, Backend-hub

---

</div>

## 🎯 Objetivo deste documento

Este documento define o **contrato técnico mínimo, explícito e auditável** entre:

- **Camada 1 — Monitoramento de Campo**
- **Camada 2 — XAI / SHAP / Inteligência Artificial**

Ele responde de forma **inequívoca**:

- ✓ O que a Camada 1 **entrega como dado**
- ✓ **Quando** esses dados estão prontos para consumo
- ✓ **Em que formato** e com **quais garantias técnicas**
- ✓ O que **não é responsabilidade** da Camada 1 no MVP

> [!IMPORTANT]
> Este contrato existe para **eliminar ambiguidade**, **evitar dependências implícitas** e **destravar a Camada 2 com segurança**.

---

## � Documentos Relacionados

Este contrato inclui os seguintes documentos anexos que detalham aspectos específicos do sistema:

- **[docs_monitoramento_relacionamento.md](docs_monitoramento_relacionamento.md)**: Documentação completa do modelo de dados e relacionamentos do sistema de monitoramento, incluindo o diagrama ER detalhado, descrições de todas as tabelas, a Query Mãe (consulta SQL completa para recuperar todos os dados de uma sessão) e exemplos de uso práticos.

- **[docs_talhao_id.md](docs_talhao_id.md)**: Documentação detalhada do campo `talhao_id`, incluindo sua definição, relacionamentos, onde é usado no código, fluxo de dados, estratégia de fallback e exemplos práticos de API.

---

## �📥 Evento de Disparo (Trigger)

### 🧠 Trigger Lógico (Produto)

A Camada 2 **pode rodar apenas quando**:

- ☑️ **finalização a sessão de monitoramento**

> [!NOTE]
> Nenhum outro evento é válido no V0.

---

### ⚙️ Trigger Técnico (Contrato)

Evidência objetiva no banco que confirma o disparo:

```sql
monitor_sessao.status = 'concluida'
```

<div align="center">

| **Evidência no Banco de Dados** | **Evidência na Interface** |
|:-------------------------------:|:--------------------------:|
| ![Banco de Dados](static/demo/trigger_banco.png) | ![Interface](static/demo/trigger_interface.png) |

</div>

> [!WARNING]
> Sessões não finalizadas **não** disparam processamento.

📌 Não existem triggers alternativos no V0 (cron, timeout, upload, etc.).

---

## 🗺️ Estrutura de Dados Contratada

### 0️⃣ Identificador do Talhão (`talhao_id`)

**Definição de talhao_id (V0)**  
No MVP (V0), `talhao_id` referencia `formulario.diagnostico.id`, representando um talhão lógico associado a uma geometria válida (`geom`).  
Este identificador é estável ao longo do tempo e serve como âncora para histórico, sessões de monitoramento e agrupamento por área.  
O `talhao_id` não representa uma sessão, mas sim a entidade lógica de área monitorada.

> [!NOTE]
> Para detalhes completos sobre `talhao_id`, consulte [docs_talhao_id.md](docs_talhao_id.md).

---

### 1️⃣ Geometria da Sessão

<table>
<tr>
<td><strong>Tipo</strong></td>
<td><code>geometry</code> (PostGIS)</td>
</tr>
<tr>
<td><strong>Subtipo esperado</strong></td>
<td><code>Polygon</code> ou <code>MultiPolygon</code></td>
</tr>
<tr>
<td><strong>SRID</strong></td>
<td><code>4326</code></td>
</tr>
<tr>
<td><strong>Origem da geometria</strong></td>
<td> Geometria gerada internamente pela Camada 1 a partir do processamento de imagens de sensoriamento remoto, resultando em zonas críticas consolidadas para o período analisado</td>
</tr>
</table>

> [!NOTE]
> **NDVI como Processo Upstream (não persistido)**  
> A origem da geometria refere-se exclusivamente ao processo interno de geração da Camada 1.  
> 
> **NDVI pode ser utilizado como processo upstream** para:
> - Identificar zonas críticas durante a geração da sessão
> - Auxiliar no posicionamento de pontos amostrais
> 
> **Importante**:
> - ❌ NDVI **não é persistido** no banco de dados
> - ❌ NDVI **não faz parte do contrato de dados** no V0
> - ❌ NDVI **não é disponibilizado** para a Camada 2
> 
> Apenas as **geometrias resultantes** (zonas, pontos, rotas) são persistidas e contratadas.

#### 📊 Validação do SRID no Banco de Dados

Consulta realizada para validação:

```sql
SELECT
    f_table_schema      AS schema,
    f_table_name        AS tabela,
    f_geometry_column   AS coluna_geom,
    type                AS tipo_geometria,
    coord_dimension     AS dimensao,
    srid
FROM public.geometry_columns
WHERE f_table_name IN (
    'monitor_obs_daninha',
    'monitor_obs_deficiencia',
    'monitor_obs_doenca',
    'monitor_obs_praga',
    'monitor_ponto',
    'monitor_rota',
    'monitor_sessao',
    'monitor_zona',
    'diagnostico'
)
ORDER BY f_table_name;
```

**Resultado da consulta:**

| Schema | Tabela | Coluna Geom | Tipo Geometria | Dimensão | SRID |
|--------|--------|-------------|----------------|----------|------|
| formulario | diagnostico | geom | MULTIPOLYGON | 2 | **4326** |
| formulario | monitor_ponto | geom | POINT | 2 | **4326** |
| formulario | monitor_rota | geom | LINESTRING | 2 | **4326** |
| formulario | monitor_zona | geom | MULTIPOLYGON | 2 | **4326** |


<div align="center">

![Resultado da Consulta SRID](static/demo/consulta_srid.png)

*Resultado da consulta SQL para validação do SRID*

</div>


#### 📍 Tabelas Utilizadas

As seguintes tabelas são utilizadas para compor a geometria da sessão:

- ☑️ `monitor_zona` — Zonas críticas detectadas
- ☑️ `monitor_rota` — Rotas percorridas durante o monitoramento
- ☑️ `monitor_ponto` — Pontos de observação em campo

---

### ✅ Garantias da Geometria

A Camada 1 garante que:

- ✓ `ST_IsValid(geometry) = true`
- ✓ Geometria sem buracos inválidos (a geometria é poligonizada a partir de pixels de imagem Sentinel-2; erros topológicos são raros e não impedem o funcionamento de sistemas Python que as coletam e tratam)
- ✓ Geometria representa apenas a área monitorada
- ✓ Geometria é recuperável para leitura e exportação

> [!IMPORTANT]
> A Camada 2 **assume esta geometria como verdade espacial**.

*Exemplo de geometria de zona crítica renderizada no sistema*

</div>

<div align="center">

| **Evidência no Banco de Dados** | **Evidência na Interface** |
|:-------------------------------:|:--------------------------:|
| <img src="static/demo/evid_demo_banco.png" alt="Banco de Dados"> | <img src="static/demo/evid_demo_interface.png" alt="Interface"> |

</div>

---

### 2️⃣ Observações de Campo

Cada observação possui:

| Campo | Tipo | Obrigatório | Observações |
|-------|------|:-----------:|-------------|
| `sessao_id` | int | ✅ | FK para `monitor_sessao` |
| `tipo` | enum | ✅ | `praga` \| `doença` \| `daninha` \| `deficiência` |
| `severidade` | enum | ✅ | `baixa` \| `moderada` \| `alta` |
| `observed_at` | timestamp | ✅ | Momento da observação |
| `nota` | text | ❌ | Texto livre |
| `foto` | text/path | ❌ | Evidência bruta |

> [!NOTE]
> **Fotos não são interpretadas no MVP.**  
> São armazenadas apenas como evidência, sem uso analítico.

> [!IMPORTANT]
> **Contrato Temporal**  
> Para detalhes completos sobre geração de timestamps, timezone (UTC), semântica dos campos `observed_at` e `created_at`, e garantias de ordenação temporal, consulte a seção **[⏰ Contrato do Tempo (V0)](#-contrato-do-tempo-v0)**.

---

### 🔢 Cardinalidade (Contrato Explícito)

```mermaid
erDiagram
    DIAGNOSTICOS ||--o{ MONITOR_SESSAO : "talhao_id"
    MONITOR_SESSAO ||--o{ MONITOR_PONTO : "possui N pontos"
    MONITOR_PONTO ||--o{ OBSERVACAO : "possui 0..N observações"
    
    DIAGNOSTICOS {
        int id PK
        string nome_talhao
        geometry geom
        string propriedade
        int cliente_id
        int usuario_id
    }
    
    MONITOR_SESSAO {
        int id PK
        int talhao_id FK
        string status
        geometry geom
    }
    
    MONITOR_PONTO {
        int id
        int sessao_id
        geometry geom
    }
    
    OBSERVACAO {
        int id
        int ponto_id
        enum tipo
        enum severidade
        timestamp observed_at
    }
```

**Regras de cardinalidade:**

- Um diagnóstico (talhão) pode ter **N sessões** de monitoramento  
  *Cada sessão representa um período específico de monitoramento para o mesmo talhão*

- Uma sessão possui **N pontos**  
  *A quantidade de pontos depende do tamanho da zona crítica detectada para o período analisado*

- Um ponto pode possuir **0..N observações**  
  *A quantidade de observações varia de acordo com as ocorrências reais observadas em campo, podendo ser uma ou mais por ponto*

- Cada observação pertence a **exatamente um ponto**  
  *Cada observação é vinculada a um ponto. Nem todos os pontos são obrigados a terem observações*

> [!IMPORTANT]
> Esta cardinalidade é **contrato conceitual e técnico** para a Camada 2.

---

## ⏰ Contrato do Tempo (V0)

### Definição Temporal Contratual

No **V0**, todos os timestamps são gerados **exclusivamente no servidor**, nunca pelo cliente.

> **⚠️ IMPORTANTE**: O timezone adotado é **UTC**, garantindo consistência temporal entre sessões e ambientes.

### Campos Temporais e Semântica

| Campo | Significado | Origem | Timezone |
|-------|-------------|--------|----------|
| `observed_at` | Momento em que o técnico **realizou a observação em campo** | Servidor | UTC |
| `created_at` | Momento em que o sistema **persistiu o registro no banco** | Servidor | UTC |

> **🔒 REGRA DE GOVERNANÇA**:  
> Esses campos **não são intercambiáveis** e possuem semânticas distintas.

### Garantias Temporais

Dentro de uma mesma sessão, os registros seguem **ordenação temporal consistente** (não regressiva):

- ✓ Os timestamps são **monotonicamente não regressivos**
- ✓ Garantia de ordem cronológica dentro da sessão
- ✓ Sem retrocessos temporais entre observações da mesma sessão

### Versionamento e Breaking Changes

> **🔒 REGRA DE GOVERNANÇA**:  
> Qualquer mudança nesta semântica temporal constitui **breaking change** e **só pode ocorrer em V1+**, com versionamento explícito.

**Exemplos de breaking changes**:
- Alterar timezone de UTC para qualquer outro
- Permitir geração de timestamps no cliente
- Modificar a semântica de `observed_at` ou `created_at`
- Quebrar a garantia de ordenação temporal não regressiva

---

## 🌱 Variáveis Ambientais

### Estado Atual (V0)

> [!WARNING]
> **NÃO fazem parte do contrato da Camada 1 no V0:**
> - NDVI
> - Chuva
> - Solo
> - Clima

📌 Estas variáveis **não são persistidas nem garantidas** pela Camada 1 no MVP.

> [!NOTE]
> **NDVI como Processo Upstream**  
> A Camada 1 pode consumir NDVI como **processo upstream** (antes da persistência) exclusivamente para:
> - Gerar zonas críticas
> - Posicionar pontos amostrais
> - Visualização descritiva temporária
> 
> **Garantias**: ❌ sem persistência | ❌ sem garantia de disponibilidade | ❌ fora do contrato de dados

---

## 🌾 Estágio da Cultura (Contrato Oficial)

### Coluna Oficial: `monitor_sessao.estagio_id`

> [!IMPORTANT]
> **Definição Contratual do Estágio:**  
> O estágio fenológico da cultura é registrado exclusivamente em `formulario.monitor_sessao.estagio_id` (FK para tabela `estagio_cultura`).

### Regra de Validade

O estágio só é considerado **válido e oficial** após:

```sql
monitor_sessao.status = 'concluida'
```

**Garantias:**
- ✓ `estagio_id` é preenchido durante a sessão de monitoramento
- ✓ `estagio_id` é informado manualmente pelo técnico em campo (não calculado)
- ✓ `estagio_id` torna-se imutável e válido após conclusão da sessão

> [!WARNING]
> **Sessões em andamento (`status != 'concluida'`)** possuem `estagio_id` **não oficial** e **não devem ser considerados** pela Camada 2.

### Campo `data_plantio` (Uso Futuro)

O campo `formulario.diagnostico.data_plantio` está disponível no banco de dados, porém:

| Campo | Uso no MVP (V0) | Uso Futuro |
|-------|----------------|------------|
| `data_plantio` | ❌ **Não utilizado para cálculos** | ✅ Cálculo de dias após plantio (DAP) para inferir estágio automaticamente |

> [!NOTE]
> **No MVP atual:**  
> - `data_plantio` é armazenado apenas para **futuras aplicações**
> - **Não é usado** para calcular dias após o plantio (DAP)
> - **Não é usado** para predizer ou validar o estágio fenológico
> - O estágio é **informado manualmente** via `monitor_sessao.estagio_id`

> [!TIP]
> **Em versões futuras (V1+):**  
> `data_plantio` poderá ser utilizado para:
> - Calcular automaticamente dias após o plantio (DAP)
> - Validar ou sugerir o estágio fenológico esperado
> - Criar alertas de inconsistência temporal

---

## 📤 Formato de Entrega dos Dados

**Formato principal (V0):**

<div align="center">

```
┌─────────────────────────────────────┐
│   PostgreSQL / PostGIS Database     │
│                                     │
│   ├── monitor_sessao                │
│   ├── monitor_zona                  │
│   ├── monitor_ponto                 │
│   ├── monitor_rota                  │
│   └── observações*                  │
└─────────────────────────────────────┘
              ▲
              │
         SQL / SQLAlchemy
              │
         (Camada 2)
```

</div>

**Acesso:**

- ☑️ Leitura direta via SQL (geralmente via SQLAlchemy em Python)

**Views:**

- Opcionais
- **Não obrigatórias** no V0

> [!CAUTION]
> Payload via API / função **não faz parte deste contrato**.

---

## 🔍 Query Mãe - Acesso Completo aos Dados de uma Sessão de Monitoramento

A **Query Mãe** é a consulta SQL completa e otimizada que recupera **todos os dados de uma sessão de monitoramento** em uma única execução, incluindo metadados, pontos, observações, rota e zonas críticas.

### Estrutura da Query

```sql
-- Query Mãe: Sessão de Monitoramento Completa
-- Parâmetros: :sessao_id (INTEGER)
-- Retorna JSON completo com todos os dados relacionados

WITH sessao_meta AS (
    -- Metadados da sessão com informações do talhão
    SELECT s.id AS sessao_id, s.talhao_id, d.nome_talhao AS talhao_nome,
           s.periodo_ini, s.periodo_fim, s.status, s.created_at,
           ST_AsGeoJSON(d.geom) AS talhao_geojson
    FROM formulario.monitor_sessao s
    LEFT JOIN formulario.diagnostico d ON d.id = s.talhao_id
    WHERE s.id = :sessao_id
),
-- [Outras CTEs: sessao_pontos, sessao_observacoes, sessao_rota, sessao_zonas, estatisticas_gerais]

SELECT 
    json_build_object('sessao_id', sm.sessao_id, 'talhao_nome', sm.talhao_nome, ...) AS metadados,
    row_to_json(eg.*) AS estatisticas,
    (SELECT json_agg(row_to_json(sp.*)) FROM sessao_pontos sp) AS pontos,
    (SELECT json_agg(row_to_json(so.*)) FROM sessao_observacoes so) AS observacoes,
    (SELECT row_to_json(sr.*) FROM sessao_rota sr) AS rota,
    (SELECT json_agg(row_to_json(sz.*)) FROM sessao_zonas sz) AS zonas
FROM sessao_meta sm
CROSS JOIN estatisticas_gerais eg;
```

### Resultado

Retorna **1 linha JSON** com toda a sessão estruturada:

```json
{
  "metadados": {"sessao_id": 456, "talhao_nome": "Talhão A", ...},
  "estatisticas": {"total_pontos": 12, "total_observacoes": 15, ...},
  "pontos": [...],
  "observacoes": [...],
  "rota": {...},
  "zonas": [...]
}
```

> [!NOTE]
> Para a **implementação completa, exemplos de uso e documentação detalhada** da Query Mãe, consulte [docs_monitoramento_relacionamento.md](docs_monitoramento_relacionamento.md).

---

## ✅ Garantias do Contrato

<div align="center">

| Garantia | Status |
|----------|:------:|
| Dados persistidos no banco | ✅ |
| Geometria válida e consistente | ✅ |
| Observações seguem contrato mínimo | ✅ |
| Histórico por sessão recuperável | ✅ |

</div>

> [!IMPORTANT]
> Toda inferência, transformação, cálculo ou decisão analítica é **responsabilidade exclusiva da Camada 2**.

---

## 🧭 Limites Explícitos do Contrato (V0)

<div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; border-radius: 10px; color: white;">

### ⚠️ Este contrato **NÃO cobre**:

<table style="width: 100%; background: rgba(255,255,255,0.1); border-radius: 8px;">
<tr>
<td style="padding: 10px;">

❌ **Inferência agronômica**  
*Nessa camada temos apenas descrição. A inferência fica para a Camada 2*

❌ **Análise de imagem**  
*Cria mapas para o relatório, mas sem análise inferencial*

❌ **NDVI / clima / solo**  
*NDVI / clima / solo não são dados contratados da Camada 1. Qualquer visualização baseada nessas variáveis é derivada externamente, efêmera e não integra o contrato de dados do MVP.*

</td>
<td style="padding: 10px;">

❌ **Scoring**  
*O banco possui catálogos de pesos e medidas para o modelo, a serem usados pela Camada 2*

❌ **Priorização**  
*Responsabilidade da Camada 2*

❌ **Explicabilidade (SHAP)**  
*Fica para a Camada 2*

❌ **Relatórios ou PDFs**  
*A Camada 1 gera um relatório inicial com mapas e gráficos descritivos*

</td>
</tr>
</table>

</div>

> [!IMPORTANT]
> Qualquer item acima pertence à Camada 2 ou camadas superiores, conforme explicado.

---

## 🏗️ Nota de Arquitetura

Este contrato:

- ✓ É versionado (V0, V1, V2…)
- ✓ Não muda sem alinhamento explícito entre camadas
- ✓ Protege o produto de deriva técnica e escopo implícito
- ✓ É **pré-requisito obrigatório** para integração da Camada 2

---

## ✅ Checklist de Evidências Obrigatórias (Aceite do Contrato)

> [!NOTE]
> Este checklist deve ser marcado pelo responsável da Camada 1.  
> Somente após todos os itens estarem comprovados, o contrato pode ser considerado **aceito**.

### 🔍 Evidências Técnicas

- [X] Existe evidência no banco de `monitor_sessao.status = 'concluida'` (Evidencia A)
- [X] A geometria associada à sessão é válida (`ST_IsValid = true`) (Evidencia B)
- [X] A geometria está no SRID 4326 (Evidencia B)
- [X] As observações possuem FK válida para ponto e sessão (Evidencia C)
- [X] Campos obrigatórios são garantidos:
	[X] tipo: garantido via UX (formulário só abre após seleção de categoria)
	[X] severidade: campo required no HTML + validação backend (Evidencia D)
	[X] observed_at: gerado automaticamente com now() 
- [X] Cardinalidade ponto ↔ observação respeitada no banco (Evidencia E (csv e print)
- [X] Sessão pode ser recuperada integralmente após finalização (Evidencia F/G)
- [X] Exportação/consulta da geometria funciona (SQL / GeoJSON / SHP) (Evidencia H/I)

#### 📸 Galeria de Evidências

<div align="center">

| Evidência A | Evidência B | Evidência C | Evidência D |
|-------------|-------------|-------------|-------------|
| <a href="static/demo/evid_a.png" target="_blank"><img src="static/demo/evid_a.png" style="width: 100px;"></a> | <a href="static/demo/evid_b.png" target="_blank"><img src="static/demo/evid_b.png" style="width: 100px;"></a> | <a href="static/demo/evid_c.png" target="_blank"><img src="static/demo/evid_c.png" style="width: 100px;"></a> | <a href="static/demo/evid_d.png" target="_blank"><img src="static/demo/evid_d.png" style="width: 100px;"></a> |

| Evidência E (CSV) | Evidência E (Print) | Evidência F | Evidência G |
|-------------------|---------------------|-------------|-------------|
| <a href="static/demo/evid_e.csv" target="_blank">Evidência E (CSV)</a> | <a href="static/demo/evid_e.png" target="_blank"><img src="static/demo/evid_e.png" style="width: 100px;"></a> | <a href="static/demo/evid_f.png" target="_blank"><img src="static/demo/evid_f.png" style="width: 100px;"></a> | <a href="static/demo/evid_g.png" target="_blank"><img src="static/demo/evid_g.png" style="width: 100px;"></a> |

| Evidência H | Evidência I |
|-------------|-------------|
| <a href="static/demo/evid_h.png" target="_blank"><img src="static/demo/evid_h.png" style="width: 100px;"></a> | <a href="static/demo/evid_i.png" target="_blank"><img src="static/demo/evid_i.png" style="width: 100px;"></a> |

</div>

<div align="center">

### 🌐 Documentação Interativa no GitHub Pages

**Acesse a documentação completa do banco e demonstrações:**  
🔗 [https://sertan-ai.github.io/documentacao-ss-camada1](https://sertan-ai.github.io/documentacao-ss-camada1)

**Acesse o Loop MVP detalhado:** [loop_monitor.md](loop_monitor.md)

#### 📱 Mockups da Documentação

| Página Inicial | Esquema Técnico Detalhado |
|:--------------:|:-------------------------:|
| <a href="static/demo/mockup_home.png" target="_blank"><img src="static/demo/mockup_home.png" alt="Página Inicial" style="width: 300px; height: auto;"></a> | <a href="static/demo/mockup_schema.png" target="_blank"><img src="static/demo/mockup_schema.png" alt="Esquema Técnico" style="width: 300px; height: auto;"></a> |

*Capturas de tela dos mockups da documentação interativa no GitHub Pages.*

</div>

---

### 🔒 Limites Confirmados

- [X] NDVI não faz parte do contrato de dados da Camada 1.
      *A Camada 1 não persiste, valida nem garante disponibilidade de NDVI.*
- [X] Precipitação não é persistida pela Camada 1
- [X] Fotos não são interpretadas no MVP
- [X] Nenhuma inferência ocorre antes do trigger oficial
- [X] O design final do relatório ainda não está definido; o design atual é uma prova de conceito

---

## 📌 Status Final

<div align="center" style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); padding: 30px; border-radius: 15px; margin: 20px 0;">

### 📋 Contrato de Dados (V0)

**Status:** ⏳ **Aguardando aceite**

**Responsável pela validação:** Samuel Santos (Camada 1)  
**Consumidores dependentes:** Silvio / Nilo / Camada 2

---

<table style="width: 100%; background: rgba(255,255,255,0.2); border-radius: 10px; margin-top: 20px;">
<tr>
<td align="center" style="padding: 15px;">
<strong>Data de criação:</strong><br>
Dezembro 2025
</td>
<td align="center" style="padding: 15px;">
<strong>Última atualização:</strong><br>
28-12-2025 (V0)
</td>
<td align="center" style="padding: 15px;">
<strong>Próxima revisão:</strong><br>
Após aceite da Camada 2
</td>
</tr>
</table>

</div>

---

<div align="center">

*Documento técnico • Sertan AI • Camada 1 — Monitoramento de Campo*

[![GitHub](https://img.shields.io/badge/GitHub-Documentação-blue?style=for-the-badge&logo=github)](https://github.com/Sertan-AI/documentacao-ss-camada1)

</div>
