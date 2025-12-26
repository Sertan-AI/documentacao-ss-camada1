# Documentação: Campo `talhao_id`

## 📋 Índice

- [O que é `talhao_id`?](#o-que-é-talhao_id)
- [Relação com Outras Tabelas](#relação-com-outras-tabelas)
- [Onde é Usado](#onde-é-usado)
- [Fluxo de Dados](#fluxo-de-dados)
- [Estratégia de Fallback](#estratégia-de-fallback)
- [Exemplos Práticos](#exemplos-práticos)

---

## O que é `talhao_id`?

**`talhao_id`** é o identificador único (chave estrangeira) que vincula uma **sessão de monitoramento** a um **talhão** específico.

### Contexto Agrícola

Um **talhão** é uma parcela ou lote de terra cultivável dentro de uma propriedade rural. Representa uma área específica delimitada geograficamente onde é plantada uma cultura (geralmente soja, neste sistema).

### Tipo de Dado

- **Tipo**: `INTEGER`
- **Obrigatório**: ✅ Sim (NOT NULL)
- **Chave Estrangeira**: Referencia `diagnosticos.id` (ou `talhoes.id` quando disponível)

---

## Relação com Outras Tabelas

### Diagrama de Relacionamento

```mermaid
erDiagram
    DIAGNOSTICOS ||--o{ MONITOR_SESSAO : "talhao_id"
    TALHOES ||--o{ MONITOR_SESSAO : "talhao_id (opcional)"
    MONITOR_SESSAO ||--o{ MONITOR_PONTO : "sessao_id"
    MONITOR_SESSAO ||--o{ MONITOR_ROTA : "sessao_id"
    MONITOR_SESSAO ||--o{ MONITOR_ZONA : "sessao_id"
    
    DIAGNOSTICOS {
        int id PK
        string nome_talhao
        geometry geom
        string propriedade
        int cliente_id
        int usuario_id
    }
    
    TALHOES {
        int id PK
        string nome
        geometry geom
    }
    
    MONITOR_SESSAO {
        int id PK
        int talhao_id FK
        date periodo_ini
        date periodo_fim
        string imagem_ref
        float total_dist_km
        string status
        int estagio_id
    }
```

### Relacionamento Principal

```sql
monitor_sessao.talhao_id → diagnosticos.id
```

> **💡 Nota Importante**: O `talhao_id` **NÃO** referencia uma tabela separada `talhoes` por padrão. Ele aponta diretamente para o `id` da tabela `diagnosticos`, que contém os dados do talhão incluindo sua geometria espacial (polígono).

---

## Onde é Usado

### 1. **Tabela `monitor_sessao`**

Coluna que armazena o ID do talhão sendo monitorado:

```sql
CREATE TABLE monitor_sessao (
    id SERIAL PRIMARY KEY,
    talhao_id INTEGER NOT NULL,       -- ← Campo principal
    periodo_ini DATE NOT NULL,
    periodo_fim DATE NOT NULL,
    imagem_ref VARCHAR(255),
    total_dist_km NUMERIC(10, 2),
    status VARCHAR(50) DEFAULT 'aberta',
    estagio_id INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### 2. **API: Listagem de Talhões** (`GET /api/talhoes`)

Endpoint que retorna os talhões disponíveis para o usuário:

**Arquivo**: [app/monitoramento/routes.py:493-544](https://github.com/Sertan-AI/sertanai-app/blob/main/app/monitoramento/routes.py#L493-L544)

```python
@bp.get("/api/talhoes")
@require_login
def listar_talhoes():
    # Busca da tabela diagnosticos
    base_sql = f"""
        SELECT DISTINCT ON (nome_talhao)
               id AS diag_id,           -- ← Este ID será o talhao_id
               nome_talhao AS nome
          FROM {t_diag}
         WHERE nome_talhao IS NOT NULL AND nome_talhao <> ''
         ORDER BY nome_talhao, id DESC
    """
    
    return jsonify([{"id": r["diag_id"], "nome": r["nome"]} for r in rows])
```

**Retorno JSON**:
```json
[
    {"id": 123, "nome": "Talhão A"},
    {"id": 124, "nome": "Talhão B"}
]
```

### 3. **API: Criar Sessão** (`POST /api/sessao`)

Endpoint que cria uma nova sessão de monitoramento:

**Arquivo**: [app/monitoramento/routes.py:666-838](https://github.com/Sertan-AI/sertanai-app/blob/main/app/monitoramento/routes.py#L666-L838)

```python
@bp.post("/api/sessao")
@require_login
def criar_sessao():
    data = request.get_json(silent=True) or {}
    talhao_id = data.get("talhao_id")      # ← Obrigatório
    periodo_ini = data.get("periodo_ini")
    periodo_fim = data.get("periodo_fim")
    estagio_id = data.get("estagio_id")
    
    # Validação
    if not (talhao_id and periodo_ini and periodo_fim):
        return jsonify({
            "ok": False, 
            "error": "missing_fields",
            "detail": "Campos obrigatórios: talhao_id, periodo_ini, periodo_fim"
        }), 400
    
    # Inserção na tabela
    conn.execute(text(f"""
        INSERT INTO {mon_table("monitor_sessao")}
        (talhao_id, periodo_ini, periodo_fim, imagem_ref, total_dist_km, status, estagio_id)
        VALUES (:tid, :pi, :pf, :img, :dist, 'aberta', :eid)
        RETURNING id
    """), {
        "tid": talhao_id,  # ← Usado aqui
        "pi": periodo_ini,
        "pf": periodo_fim,
        # ...
    })
```

**Payload de Exemplo**:
```json
{
    "talhao_id": 123,
    "periodo_ini": "2024-01-01",
    "periodo_fim": "2024-01-15",
    "estagio_id": 2
}
```

### 4. **API: Listar Sessões** (`GET /api/sessoes`)

Filtro opcional por `talhao_id`:

**Arquivo**: [app/monitoramento/routes.py:1320-1358](https://github.com/Sertan-AI/sertanai-app/blob/main/app/monitoramento/routes.py#L1320-L1358)

```python
@bp.get("/api/sessoes")
@require_login
def listar_sessoes():
    talhao_id = request.args.get("talhao_id", type=int)  # ← Filtro opcional
    
    if talhao_id is not None:
        filtros.append("s.talhao_id = :tid")
        params["tid"] = talhao_id
```

**Exemplo de Chamada**:
```
GET /api/sessoes?talhao_id=123
```

### 5. **Interface Frontend** (JavaScript)

**Arquivo**: [app/templates/monitoramento/index.html:756-769](https://github.com/Sertan-AI/sertanai-app/blob/main/app/templates/monitoramento/index.html#L756-L769)

```javascript
// Captura o ID do talhão selecionado no formulário
const talhao_id = parseInt(el("selTalhao").value);
const estagio_id = parseInt(el("selEstagio").value);
const periodo_ini = el("inpPeriodoIni").value;
const periodo_fim = el("inpPeriodoFim").value;

// Validação
if (!talhao_id || !estagio_id || !periodo_ini || !periodo_fim) {
    alert("Preencha todos os campos");
    return;
}

// Envia para criar sessão
fetch("/api/sessao", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ talhao_id, estagio_id, periodo_ini, periodo_fim })
});
```

### 6. **Exibição de Informações da Sessão**

**Arquivo**: [app/templates/monitoramento/index.html:792](https://github.com/Sertan-AI/sertanai-app/blob/main/app/templates/monitoramento/index.html#L792)

```javascript
// Exibe informações da sessão ativa
el("sessaoInfo").textContent = 
    `Sessão #${s.id} • Talhão ${s.talhao_id} • ${s.periodo_ini} a ${s.periodo_fim} • ${s.status}`;
```

---

## Fluxo de Dados

### Criação de uma Sessão de Monitoramento

```mermaid
sequenceDiagram
    participant U as Usuário
    participant F as Frontend
    participant API as Backend API
    participant DB as Banco de Dados
    
    U->>F: Seleciona talhão no dropdown
    F->>API: GET /api/talhoes
    API->>DB: SELECT id, nome_talhao FROM diagnosticos
    DB-->>API: [{id: 123, nome: "Talhão A"}]
    API-->>F: Lista de talhões
    
    U->>F: Preenche período e clica "Criar Sessão"
    F->>API: POST /api/sessao {talhao_id: 123, periodo_ini, periodo_fim}
    
    API->>DB: SELECT geom FROM diagnosticos WHERE id = 123
    DB-->>API: Geometria (polígono) do talhão
    
    API->>API: Gera pontos amostrais e rota
    
    API->>DB: INSERT INTO monitor_sessao (talhao_id, ...)
    API->>DB: INSERT INTO monitor_ponto (sessao_id, ...)
    API->>DB: INSERT INTO monitor_rota (sessao_id, ...)
    
    DB-->>API: Sessão criada (id: 456)
    API-->>F: Dados da sessão + pontos + rota
    F-->>U: Exibe mapa com pontos e rota
```

### Consulta de Sessão Existente

```mermaid
sequenceDiagram
    participant F as Frontend
    participant API as Backend API
    participant DB as Banco de Dados
    
    F->>API: GET /api/sessao/456
    
    API->>DB: SELECT * FROM monitor_sessao WHERE id = 456
    Note over DB: Retorna: talhao_id = 123
    
    API->>DB: SELECT nome_talhao FROM diagnosticos WHERE id = 123
    API->>DB: SELECT * FROM monitor_ponto WHERE sessao_id = 456
    API->>DB: SELECT * FROM monitor_rota WHERE sessao_id = 456
    
    DB-->>API: Dados completos da sessão
    API-->>F: JSON com sessão, pontos, rota, talhão
```

---

## Estratégia de Fallback

O sistema usa uma **estratégia dupla** para buscar informações do talhão:

### 1. Tentativa Primária: Tabela `talhoes` (opcional)

```python
if talhoes_exists:
    talhao = conn.execute(text(f"""
        SELECT id, ST_AsText(geom) AS wkt, nome
          FROM {t_talhoes}
         WHERE id = :tid
    """), {"tid": talhao_id}).mappings().first()
```

### 2. Fallback: Tabela `diagnosticos` (sempre presente)

```python
if not talhao:
    talhao = conn.execute(text(f"""
        SELECT id, ST_AsText(geom) AS wkt, nome_talhao AS nome
          FROM {diagnosticos_table()}
         WHERE id = :tid
    """), {"tid": talhao_id}).mappings().first()
```

### 3. JOIN para Nome do Talhão

Ao buscar metadados da sessão, faz JOIN com ambas as tabelas usando `COALESCE`:

```sql
SELECT s.id, s.talhao_id, s.periodo_ini, s.periodo_fim,
       COALESCE(t.nome, d.nome_talhao) AS talhao_nome
  FROM monitor_sessao s
  LEFT JOIN talhoes t ON t.id = s.talhao_id           -- Tenta primeiro
  LEFT JOIN diagnosticos d ON d.id = s.talhao_id      -- Fallback
 WHERE s.id = :sid
```

**Lógica**:
- Se `talhoes.nome` existir → usa ele
- Caso contrário → usa `diagnosticos.nome_talhao`

---

## Exemplos Práticos

### Exemplo 1: Criar Sessão via API

**Request**:
```bash
curl -X POST http://localhost:5000/api/sessao \
  -H "Content-Type: application/json" \
  -d '{
    "talhao_id": 123,
    "periodo_ini": "2024-01-01",
    "periodo_fim": "2024-01-15",
    "estagio_id": 2
  }'
```

**Response**:
```json
{
  "sessao": {
    "id": 456,
    "talhao_id": 123,
    "talhao_nome": "Talhão A - Soja",
    "periodo_ini": "2024-01-01",
    "periodo_fim": "2024-01-15",
    "imagem_ref": "2024-01-10",
    "total_dist_km": 2.5,
    "status": "aberta",
    "estagio_id": 2
  },
  "pontos": [
    {"id": 1, "pt_seq": 1, "lon": -47.123, "lat": -15.456, "status": {}},
    {"id": 2, "pt_seq": 2, "lon": -47.124, "lat": -15.457, "status": {}}
  ],
  "rota": {
    "type": "LineString",
    "coordinates": [[-47.123, -15.456], [-47.124, -15.457]]
  }
}
```

### Exemplo 2: Listar Sessões de um Talhão Específico

**Request**:
```bash
curl http://localhost:5000/api/sessoes?talhao_id=123
```

**Response**:
```json
[
  {
    "id": 456,
    "talhao_id": 123,
    "talhao_nome": "Talhão A - Soja",
    "periodo_ini": "2024-01-01",
    "periodo_fim": "2024-01-15",
    "status": "concluida",
    "total_obs": 15
  },
  {
    "id": 789,
    "talhao_id": 123,
    "talhao_nome": "Talhão A - Soja",
    "periodo_ini": "2024-02-01",
    "periodo_fim": "2024-02-15",
    "status": "aberta",
    "total_obs": 3
  }
]
```

### Exemplo 3: Query SQL Completa

Buscar todas as sessões com informações do talhão:

```sql
SELECT 
    s.id AS sessao_id,
    s.talhao_id,
    COALESCE(t.nome, d.nome_talhao) AS talhao_nome,
    d.propriedade,
    s.periodo_ini,
    s.periodo_fim,
    s.status,
    s.total_dist_km,
    COUNT(DISTINCT p.id) AS total_pontos,
    COUNT(DISTINCT obs.id) AS total_observacoes
FROM monitor_sessao s
LEFT JOIN talhoes t ON t.id = s.talhao_id
LEFT JOIN diagnosticos d ON d.id = s.talhao_id
LEFT JOIN monitor_ponto p ON p.sessao_id = s.id
LEFT JOIN monitor_obs_praga obs ON obs.ponto_id = p.id
WHERE s.status = 'aberta'
GROUP BY s.id, s.talhao_id, t.nome, d.nome_talhao, d.propriedade
ORDER BY s.created_at DESC;
```

---

## Considerações Importantes

### ⚠️ Pontos de Atenção

1. O `talhao_id` referencia `diagnosticos.id`, **não** uma tabela `talhoes` dedicada
2. A geometria do talhão **deve existir** (`geom NOT NULL`) para gerar pontos/rota
3. A estratégia de fallback garante compatibilidade se uma tabela `talhoes` for adicionada futuramente

### 🔐 Segurança

- Filtros por `cliente_id` e `usuario_id` garantem isolamento de dados
- Usuários só veem talhões aos quais têm acesso.

---

## Referências de Código

| Local | Arquivo | Linhas |
|-------|---------|--------|
| Listar Talhões | [app/monitoramento/routes.py](https://github.com/Sertan-AI/sertanai-app/blob/main/app/monitoramento/routes.py#L493-L544) | 493-544 |
| Criar Sessão | [app/monitoramento/routes.py](https://github.com/Sertan-AI/sertanai-app/blob/main/app/monitoramento/routes.py#L666-L838) | 666-838 |
| Buscar Geometria | [app/monitoramento/routes.py](https://github.com/Sertan-AI/sertanai-app/blob/main/app/monitoramento/routes.py#L698-L730) | 698-730 |
| Payload Sessão | [app/monitoramento/routes.py](https://github.com/Sertan-AI/sertanai-app/blob/main/app/monitoramento/routes.py#L849-L927) | 849-927 |
| Frontend - Criar | [app/templates/monitoramento/index.html](https://github.com/Sertan-AI/sertanai-app/blob/main/app/templates/monitoramento/index.html#L756-L769) | 756-769 |
| Frontend - Listar | [app/templates/monitoramento/index.html](https://github.com/Sertan-AI/sertanai-app/blob/main/app/templates/monitoramento/index.html#L1180) | 1180 |

---

**Última atualização**: 2024-12-25
