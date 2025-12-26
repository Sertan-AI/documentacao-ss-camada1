# Sistema de Monitoramento - Modelo de Dados e Relacionamentos

## 📋 Visão Geral

O sistema de **monitoramento de campo** permite criar sessões de coleta de dados em talhões agrícolas, com pontos amostrais para registro de observações sobre pragas, doenças, plantas daninhas e deficiências nutricionais.

---

## 🗺️ Diagrama de Relacionamento (ERD)

```mermaid
erDiagram
    diagnostico ||--o{ MONITOR_SESSAO : "talhao_id"
    MONITOR_SESSAO ||--o{ MONITOR_PONTO : "sessao_id"
    MONITOR_SESSAO ||--o{ MONITOR_ROTA : "sessao_id"
    MONITOR_SESSAO ||--o{ MONITOR_ZONA : "sessao_id"
    MONITOR_PONTO ||--o{ MONITOR_OBS_PRAGA : "ponto_id"
    MONITOR_PONTO ||--o{ MONITOR_OBS_DOENCA : "ponto_id"
    MONITOR_PONTO ||--o{ MONITOR_OBS_DANINHA : "ponto_id"
    MONITOR_PONTO ||--o{ MONITOR_OBS_DEFICIENCIA : "ponto_id"
    PRAGAS ||--o{ MONITOR_OBS_PRAGA : "praga_id"
    DOENCAS_SOJA ||--o{ MONITOR_OBS_DOENCA : "doenca_id"
    PLANTAS_DANINHAS ||--o{ MONITOR_OBS_DANINHA : "daninha_id"
    DEFICIENCIAS_NUTRICIONAIS_SOJA ||--o{ MONITOR_OBS_DEFICIENCIA : "deficiencia_id"
    ESTAGIOS_FENOLOGICOS ||--o{ MONITOR_SESSAO : "estagio_id"

    diagnostico {
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
        date periodo_ini
        date periodo_fim
        string imagem_ref
        float total_dist_km
        string status
        int estagio_id FK
        timestamp created_at
    }

    MONITOR_PONTO {
        int id PK
        int sessao_id FK
        int pt_seq
        geometry geom
        boolean zona_critica
    }

    MONITOR_ROTA {
        int id PK
        int sessao_id FK
        geometry geom
    }

    MONITOR_ZONA {
        int id PK
        int sessao_id FK
        int classe
        geometry geom
    }

    MONITOR_OBS_PRAGA {
        int id PK
        int ponto_id FK
        int praga_id FK
        string severidade
        string notas
        string foto_path
        timestamp observed_at
    }

    MONITOR_OBS_DOENCA {
        int id PK
        int ponto_id FK
        int doenca_id FK
        string severidade
        string notas
        string foto_path
        timestamp observed_at
    }

    MONITOR_OBS_DANINHA {
        int id PK
        int ponto_id FK
        int daninha_id FK
        string severidade
        string notas
        string foto_path
        timestamp observed_at
    }

    MONITOR_OBS_DEFICIENCIA {
        int id PK
        int ponto_id FK
        int deficiencia_id FK
        string severidade
        string notas
        string foto_path
        timestamp observed_at
    }
```

> **💡 Nota Importante sobre `talhao_id`**: 
> - O campo `talhao_id` em `monitor_sessao` referencia **diretamente `diagnostico.id`**
> - **Não existe uma tabela `talhoes` separada** no banco de dados atual
> - Cada registro em `diagnostico` representa um talhão com sua geometria (`geom`) e metadados
> - O código Python possui uma estratégia de fallback que busca primeiro em `talhoes` (se existir futuramente) e depois em `diagnostico`

---

## 📊 Estrutura de uma Sessão de Monitoramento Completa

### Hierarquia de Dados

```
📦 SESSÃO DE MONITORAMENTO
│
├── 📄 Metadados da Sessão (monitor_sessao)
│   ├── Talhão (referência a diagnostico)
│   ├── Período de coleta
│   ├── Estágio fenológico
│   └── Status (aberta/concluida)
│
├── 🗺️ Dados Espaciais
│   ├── Rota de coleta (monitor_rota)
│   └── Zonas críticas (monitor_zona)
│
├── 📍 Pontos Amostrais (monitor_ponto)
│   └── Para cada ponto:
│       ├── 🐛 Observações de Pragas (monitor_obs_praga)
│       ├── 🦠 Observações de Doenças (monitor_obs_doenca)
│       ├── 🌿 Observações de Daninhas (monitor_obs_daninha)
│       └── 🍃 Observações de Deficiências (monitor_obs_deficiencia)
```

---

## 📋 Descrição das Tabelas

### 1. `monitor_sessao` - Sessão de Monitoramento (Tabela Central)

Representa uma campanha de monitoramento em um talhão específico durante um período.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | SERIAL | Identificador único da sessão |
| `talhao_id` | INTEGER | FK para `diagnostico.id` (talhão monitorado) |
| `periodo_ini` | DATE | Data de início do período de monitoramento |
| `periodo_fim` | DATE | Data de fim do período de monitoramento |
| `imagem_ref` | VARCHAR | Referência da imagem satélite usada (ex: "2024-01-10") |
| `total_dist_km` | NUMERIC | Distância total da rota em km |
| `status` | VARCHAR | Status da sessão: `aberta` ou `concluida` |
| `estagio_id` | INTEGER | FK para estágio fenológico da cultura |
| `created_at` | TIMESTAMP | Data/hora de criação da sessão |

**Regra de Negócio**: Uma sessão é única por combinação de `(talhao_id, periodo_ini, periodo_fim)`.

---

### 2. `monitor_ponto` - Pontos Amostrais

Pontos de coleta de dados gerados automaticamente dentro do talhão.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | SERIAL | Identificador único do ponto |
| `sessao_id` | INTEGER | FK para `monitor_sessao.id` |
| `pt_seq` | INTEGER | Sequência do ponto na rota (1, 2, 3...) |
| `geom` | GEOMETRY(Point, 4326) | Coordenada geográfica (lat/lon) |
| `zona_critica` | BOOLEAN | Se o ponto está em zona crítica (NDVI baixo) |

**Quantidade Típica**: 12 pontos por sessão (gerados automaticamente).

---

### 3. `monitor_rota` - Rota de Coleta

LineString conectando os pontos na ordem ideal de visitação.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | SERIAL | Identificador único da rota |
| `sessao_id` | INTEGER | FK para `monitor_sessao.id` |
| `geom` | GEOMETRY(LineString, 4326) | Geometria da rota |

**Cardinalidade**: 1 rota por sessão.

---

### 4. `monitor_zona` - Zonas Críticas

Áreas problemáticas identificadas por análise de imagens de satélite (NDVI).

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | SERIAL | Identificador único da zona |
| `sessao_id` | INTEGER | FK para `monitor_sessao.id` |
| `classe` | INTEGER | Classe de criticidade (0=crítica, 1=média, 2=boa) |
| `geom` | GEOMETRY(MultiPolygon, 4326) | Geometria da zona |

**Fonte**: Geradas via Google Earth Engine analisando NDVI do Sentinel-2.

---

### 5-8. Tabelas de Observações

Cada ponto pode ter múltiplas observações de diferentes categorias.

#### `monitor_obs_praga` - Observações de Pragas

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | SERIAL | Identificador único |
| `ponto_id` | INTEGER | FK para `monitor_ponto.id` |
| `praga_id` | INTEGER | FK para `pragas.id` |
| `severidade` | VARCHAR | `baixa`, `moderada` ou `alta` |
| `notas` | TEXT | Observações adicionais |
| `foto_path` | VARCHAR | Caminho da foto (se houver) |
| `observed_at` | TIMESTAMP | Data/hora da observação |

#### `monitor_obs_doenca` - Observações de Doenças

Estrutura idêntica, referenciando `doencas_soja.id`.

#### `monitor_obs_daninha` - Observações de Plantas Daninhas

Estrutura idêntica, referenciando `plantas_daninhas.id`.

#### `monitor_obs_deficiencia` - Observações de Deficiências Nutricionais

Estrutura idêntica, referenciando `deficiencias_nutricionais_soja.id`.

---

## 🔍 Query SQL Mãe - Sessão Completa

### Query Completa para Buscar Todos os Dados de uma Sessão

```sql
-- ============================================================================
-- QUERY MÃE: Sessão de Monitoramento Completa
-- ============================================================================
-- Parâmetros: :sessao_id (INTEGER)
-- Retorna todos os dados relacionados a uma sessão de monitoramento
-- ============================================================================

WITH sessao_meta AS (
    -- Metadados da sessão com informações do talhão
    SELECT 
        s.id AS sessao_id,
        s.talhao_id,
        d.nome_talhao AS talhao_nome,
        d.propriedade,
        s.periodo_ini,
        s.periodo_fim,
        s.imagem_ref,
        s.total_dist_km,
        s.status,
        s.estagio_id,
        ef.descricao AS estagio_nome,
        s.created_at,
        ST_AsGeoJSON(d.geom) AS talhao_geojson
    FROM formulario.monitor_sessao s
    LEFT JOIN formulario.diagnostico d ON d.id = s.talhao_id
    LEFT JOIN formulario.estagios_soja ef ON ef.id = s.estagio_id
    WHERE s.id = :sessao_id
),

sessao_pontos AS (
    -- Pontos amostrais com contagem de observações por categoria
    SELECT 
        p.id AS ponto_id,
        p.sessao_id,
        p.pt_seq,
        ST_X(p.geom) AS lon,
        ST_Y(p.geom) AS lat,
        p.zona_critica,
        ST_AsGeoJSON(p.geom) AS ponto_geojson,
        
        -- Contadores de observações por ponto
        COUNT(DISTINCT op.id) AS total_obs_pragas,
        COUNT(DISTINCT od.id) AS total_obs_doencas,
        COUNT(DISTINCT oda.id) AS total_obs_daninhas,
        COUNT(DISTINCT odf.id) AS total_obs_deficiencias,
        
        -- Total geral de observações
        (COUNT(DISTINCT op.id) + COUNT(DISTINCT od.id) + 
         COUNT(DISTINCT oda.id) + COUNT(DISTINCT odf.id)) AS total_observacoes,
        
        -- Status do preenchimento
        (COUNT(DISTINCT op.id) > 0) AS tem_praga,
        (COUNT(DISTINCT od.id) > 0) AS tem_doenca,
        (COUNT(DISTINCT oda.id) > 0) AS tem_daninha,
        (COUNT(DISTINCT odf.id) > 0) AS tem_deficiencia
        
    FROM formulario.monitor_ponto p
    LEFT JOIN formulario.monitor_obs_praga op ON op.ponto_id = p.id
    LEFT JOIN formulario.monitor_obs_doenca od ON od.ponto_id = p.id
    LEFT JOIN formulario.monitor_obs_daninha oda ON oda.ponto_id = p.id
    LEFT JOIN formulario.monitor_obs_deficiencia odf ON odf.ponto_id = p.id
    WHERE p.sessao_id = :sessao_id
    GROUP BY p.id, p.sessao_id, p.pt_seq, p.geom, p.zona_critica
    ORDER BY p.pt_seq
),

sessao_observacoes AS (
    -- Todas as observações detalhadas de todos os pontos
    SELECT 
        'praga' AS categoria,
        op.id AS obs_id,
        op.ponto_id,
        p.pt_seq,
        op.praga_id AS alvo_id,
        pr.nome_comum AS alvo_nome,
        op.severidade,
        op.notas,
        op.foto_path,
        op.observed_at
    FROM formulario.monitor_obs_praga op
    JOIN formulario.monitor_ponto p ON p.id = op.ponto_id
    LEFT JOIN formulario.pragas pr ON pr.id = op.praga_id
    WHERE p.sessao_id = :sessao_id
    
    UNION ALL
    
    SELECT 
        'doenca' AS categoria,
        od.id AS obs_id,
        od.ponto_id,
        p.pt_seq,
        od.doenca_id AS alvo_id,
        d."Nome Popular" AS alvo_nome,
        od.severidade,
        od.notas,
        od.foto_path,
        od.observed_at
    FROM formulario.monitor_obs_doenca od
    JOIN formulario.monitor_ponto p ON p.id = od.ponto_id
    LEFT JOIN formulario.doencas_soja d ON d.id = od.doenca_id
    WHERE p.sessao_id = :sessao_id
    
    UNION ALL
    
    SELECT 
        'daninha' AS categoria,
        oda.id AS obs_id,
        oda.ponto_id,
        p.pt_seq,
        oda.daninha_id AS alvo_id,
        da.nome_popular AS alvo_nome,
        oda.severidade,
        oda.notas,
        oda.foto_path,
        oda.observed_at
    FROM formulario.monitor_obs_daninha oda
    JOIN formulario.monitor_ponto p ON p.id = oda.ponto_id
    LEFT JOIN formulario.plantas_daninhas da ON da.id = oda.daninha_id
    WHERE p.sessao_id = :sessao_id
    
    UNION ALL
    
    SELECT 
        'deficiencia' AS categoria,
        odf.id AS obs_id,
        odf.ponto_id,
        p.pt_seq,
        odf.deficiencia_id AS alvo_id,
        df.nutriente AS alvo_nome,
        odf.severidade,
        odf.notas,
        odf.foto_path,
        odf.observed_at
    FROM formulario.monitor_obs_deficiencia odf
    JOIN formulario.monitor_ponto p ON p.id = odf.ponto_id
    LEFT JOIN formulario.deficiencias_nutricionais_soja df ON df.id = odf.deficiencia_id
    WHERE p.sessao_id = :sessao_id
    
    ORDER BY pt_seq, categoria, observed_at DESC
),

sessao_rota AS (
    -- Geometria da rota
    SELECT 
        r.sessao_id,
        ST_Length(r.geom::geography) / 1000 AS dist_calculada_km,
        ST_AsGeoJSON(r.geom) AS rota_geojson
    FROM formulario.monitor_rota r
    WHERE r.sessao_id = :sessao_id
),

sessao_zonas AS (
    -- Zonas críticas identificadas
    SELECT 
        z.id AS zona_id,
        z.sessao_id,
        z.classe,
        CASE z.classe
            WHEN 0 THEN 'Crítica'
            WHEN 1 THEN 'Média'
            WHEN 2 THEN 'Boa'
            ELSE 'Desconhecida'
        END AS classe_desc,
        ST_Area(z.geom::geography) / 10000 AS area_ha,
        ST_AsGeoJSON(z.geom) AS zona_geojson
    FROM formulario.monitor_zona z
    WHERE z.sessao_id = :sessao_id
    ORDER BY z.classe
),

estatisticas_gerais AS (
    -- Estatísticas agregadas da sessão
    SELECT
        :sessao_id AS sessao_id,
        COUNT(DISTINCT p.id) AS total_pontos,
        COUNT(DISTINCT CASE WHEN (op.id IS NOT NULL OR od.id IS NOT NULL OR 
                                   oda.id IS NOT NULL OR odf.id IS NOT NULL) 
                            THEN p.id END) AS pontos_com_observacoes,
        COUNT(DISTINCT op.id) AS total_obs_pragas,
        COUNT(DISTINCT od.id) AS total_obs_doencas,
        COUNT(DISTINCT oda.id) AS total_obs_daninhas,
        COUNT(DISTINCT odf.id) AS total_obs_deficiencias,
        (COUNT(DISTINCT op.id) + COUNT(DISTINCT od.id) + 
         COUNT(DISTINCT oda.id) + COUNT(DISTINCT odf.id)) AS total_observacoes_geral,
        
        -- Severidades (contadores)
        SUM(CASE WHEN op.severidade = 'alta' OR od.severidade = 'alta' OR 
                      oda.severidade = 'alta' OR odf.severidade = 'alta' 
                 THEN 1 ELSE 0 END) AS obs_severidade_alta,
        SUM(CASE WHEN op.severidade = 'moderada' OR od.severidade = 'moderada' OR 
                      oda.severidade = 'moderada' OR odf.severidade = 'moderada' 
                 THEN 1 ELSE 0 END) AS obs_severidade_moderada,
        SUM(CASE WHEN op.severidade = 'baixa' OR od.severidade = 'baixa' OR 
                      oda.severidade = 'baixa' OR odf.severidade = 'baixa' 
                 THEN 1 ELSE 0 END) AS obs_severidade_baixa
                 
    FROM formulario.monitor_ponto p
    LEFT JOIN formulario.monitor_obs_praga op ON op.ponto_id = p.id
    LEFT JOIN formulario.monitor_obs_doenca od ON od.ponto_id = p.id
    LEFT JOIN formulario.monitor_obs_daninha oda ON oda.ponto_id = p.id
    LEFT JOIN formulario.monitor_obs_deficiencia odf ON odf.ponto_id = p.id
    WHERE p.sessao_id = :sessao_id
)

-- ============================================================================
-- RESULTADO FINAL: Combine todas as CTEs para visão completa
-- ============================================================================
SELECT 
    -- Metadados
    json_build_object(
        'sessao_id', sm.sessao_id,
        'talhao_id', sm.talhao_id,
        'talhao_nome', sm.talhao_nome,
        'propriedade', sm.propriedade,
        'periodo_ini', sm.periodo_ini,
        'periodo_fim', sm.periodo_fim,
        'imagem_ref', sm.imagem_ref,
        'total_dist_km', sm.total_dist_km,
        'status', sm.status,
        'estagio_id', sm.estagio_id,
        'estagio_nome', sm.estagio_nome,
        'created_at', sm.created_at,
        'talhao_geojson', sm.talhao_geojson
    ) AS metadados,
    
    -- Estatísticas
    row_to_json(eg.*) AS estatisticas,
    
    -- Pontos (array de objetos JSON)
    (SELECT json_agg(row_to_json(sp.*) ORDER BY sp.pt_seq) 
     FROM sessao_pontos sp) AS pontos,
    
    -- Observações (array de objetos JSON)
    (SELECT json_agg(row_to_json(so.*) ORDER BY so.pt_seq, so.categoria, so.observed_at DESC) 
     FROM sessao_observacoes so) AS observacoes,
    
    -- Rota
    (SELECT row_to_json(sr.*) FROM sessao_rota sr) AS rota,
    
    -- Zonas (array de objetos JSON)
    (SELECT json_agg(row_to_json(sz.*) ORDER BY sz.classe) 
     FROM sessao_zonas sz) AS zonas

FROM sessao_meta sm
CROSS JOIN estatisticas_gerais eg;
```

---

## 📝 Exemplo de Uso da Query Mãe

### Consultar Sessão #456

```sql
-- Substituir :sessao_id por 456
-- Todas as CTEs da query mãe usam este parâmetro

SELECT * FROM (
    -- [QUERY MÃE COMPLETA AQUI]
    -- Onde :sessao_id = 456
) resultado;
```

### Resultado Esperado

A query retorna **1 linha** com todas as informações em formato JSON:

```json
{
  "metadados": {
    "sessao_id": 456,
    "talhao_id": 123,
    "talhao_nome": "Talhão Sul A",
    "propriedade": "Fazenda Santa Maria",
    "periodo_ini": "2024-01-01",
    "periodo_fim": "2024-01-15",
    "imagem_ref": "2024-01-10",
    "total_dist_km": 2.5,
    "status": "concluida",
    "estagio_id": 2,
    "estagio_nome": "V4",
    "created_at": "2024-01-01T08:00:00"
  },
  "estatisticas": {
    "total_pontos": 12,
    "pontos_com_observacoes": 8,
    "total_obs_pragas": 5,
    "total_obs_doencas": 3,
    "total_obs_daninhas": 2,
    "total_obs_deficiencias": 1,
    "total_observacoes_geral": 11,
    "obs_severidade_alta": 2,
    "obs_severidade_moderada": 6,
    "obs_severidade_baixa": 3
  },
  "pontos": [...],
  "observacoes": [...],
  "rota": {...},
  "zonas": [...]
}
```

---

## 🎯 Casos de Uso

### Caso 1: Criar uma Sessão Completa

```python
# 1. Criar sessão
INSERT INTO formulario.monitor_sessao 
    (talhao_id, periodo_ini, periodo_fim, status, estagio_id)
VALUES (123, '2024-01-01', '2024-01-15', 'aberta', 2)
RETURNING id;  -- Retorna 456

# 2. Inserir pontos (12x)
INSERT INTO formulario.monitor_ponto (sessao_id, pt_seq, geom)
VALUES (456, 1, ST_GeomFromText('POINT(-47.123 -15.456)', 4326));
-- ... repetir para os 12 pontos

# 3. Inserir rota
INSERT INTO formulario.monitor_rota (sessao_id, geom)
VALUES (456, ST_GeomFromText('LINESTRING(...)', 4326));

# 4. Usuário coleta dados no campo e salva observações
INSERT INTO formulario.monitor_obs_praga (ponto_id, praga_id, severidade, notas)
VALUES (1001, 5, 'moderada', 'Lagarta presente em 30% das plantas');
```

### Caso 2: Consultar Progresso de uma Sessão

```sql
SELECT 
    COUNT(*) AS total_pontos,
    SUM(CASE WHEN tem_observacoes THEN 1 ELSE 0 END) AS pontos_preenchidos,
    ROUND(
        SUM(CASE WHEN tem_observacoes THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
        2
    ) AS percentual_completo
FROM (
    SELECT 
        p.id,
        EXISTS (
            SELECT 1 FROM formulario.monitor_obs_praga WHERE ponto_id = p.id
            UNION ALL
            SELECT 1 FROM formulario.monitor_obs_doenca WHERE ponto_id = p.id
            UNION ALL
            SELECT 1 FROM formulario.monitor_obs_daninha WHERE ponto_id = p.id
            UNION ALL
            SELECT 1 FROM formulario.monitor_obs_deficiencia WHERE ponto_id = p.id
        ) AS tem_observacoes
    FROM formulario.monitor_ponto p
    WHERE p.sessao_id = 456
) pontos_status;
```

### Caso 3: Concluir Sessão

```sql
UPDATE formulario.monitor_sessao 
SET status = 'concluida' 
WHERE id = 456;
```

---

## 📌 Regras de Negócio Importantes

1. **Unicidade de Sessão**: Não podem existir duas sessões com mesmo `(talhao_id, periodo_ini, periodo_fim)` em status `aberta`

2. **Severidade Obrigatória**: Todas as observações DEVEM ter severidade (`baixa`, `moderada` ou `alta`)

3. **Cascata de Deleção**: Ao deletar uma sessão, todos os pontos, rota, zonas e observações são deletados automaticamente

4. **Pontos Sequenciais**: Os pontos devem ter `pt_seq` de 1 a N sem pulos

5. **Geometrias válidas**: Todas as geometrias devem estar em SRID 4326 (WGS84)

---

## 🔐 Controle de Acesso

Sessões pertencem ao usuário/cliente que criou o diagnóstico do talhão:

```sql
-- Verificar permissão de acesso
SELECT s.* 
FROM formulario.monitor_sessao s
JOIN diagnostico d ON d.id = s.talhao_id
WHERE s.id = :sessao_id
  AND (d.cliente_id = :cliente_id OR d.usuario_id = :usuario_id);
```

---

**Última atualização**: 2024-12-25
