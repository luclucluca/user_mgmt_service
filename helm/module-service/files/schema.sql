CREATE TABLE IF NOT EXISTS modules (
    id CHAR(36) NOT NULL,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE INDEX ix_modules_code (code)
);

CREATE TABLE IF NOT EXISTS users_modules (
    user_id CHAR(36) NOT NULL,
    module_id CHAR(36) NOT NULL,
    assigned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, module_id),
    INDEX ix_users_modules_module_id (module_id),
    CONSTRAINT fk_users_modules_module
        FOREIGN KEY (module_id) REFERENCES modules (id) ON DELETE CASCADE
);

INSERT IGNORE INTO modules (id, code, name, description)
VALUES
    (
        'c02f58f2-3aca-4f1e-8076-bacf6f1999e6',
        'CLOUD-ARCH',
        'Cloud Architecture',
        'Designing reliable and scalable cloud systems'
    ),
    (
        '6d5889ee-f4c7-44d7-a887-da92d2a51ac4',
        'DATABASES',
        'Database Systems',
        'Relational data modeling and SQL fundamentals'
    ),
    (
        '674ca4e0-6334-4b12-aa83-d97895049b8a',
        'SECURITY',
        'Application Security',
        'Secure software design and common vulnerabilities'
    ),
    (
        '4b9ff45a-d90f-42b0-8b72-20f0b92b6027',
        'WEB-DEV',
        'Web Development',
        'Building modern web applications and APIs'
    );
