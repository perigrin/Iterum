-- ECS Schema
-- Based on entity-systems-are-the-future-of-mmos-part-5 by t-machine

-- 1 assemblages
CREATE TABLE IF NOT EXISTS assemblages (
    id TEXT PRIMARY KEY,
    label TEXT UNIQUE NOT NULL,
    description TEXT
);

-- 2 assemblage_components
CREATE TABLE IF NOT EXISTS assemblage_components (
    assemblage_id TEXT,
    component_id TEXT,
    PRIMARY KEY (assemblage_id, component_id)
);

--  3 components
CREATE TABLE IF NOT EXISTS components (
    id TEXT PRIMARY KEY,
    label TEXT UNIQUE NOT NULL,
    description TEXT
);

--  4 entities
CREATE TABLE IF NOT EXISTS entities (
    id TEXT PRIMARY KEY,
    label TEXT
);

-- 5 entity_components
CREATE TABLE IF NOT EXISTS entity_components (
    entity_id TEXT,
    component_id TEXT,
    component_data JSON,
    PRIMARY KEY (entity_id, component_id)
);
