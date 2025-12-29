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