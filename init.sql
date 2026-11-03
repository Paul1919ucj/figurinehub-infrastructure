CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(1) NOT NULL,
    image VARCHAR(255) NOT NULL
);

INSERT INTO products (name, category, image) VALUES
('Figurina Naruto', 'A', 'naruto.jpg'),
('Figurina Boruto', 'A', 'boruto.jpg'),
('Figurina Goku', 'B', 'goku.jpg'),
('Figurina Batman', 'B', 'batman.jpg'),
('Figurina Spider-Man', 'C', 'spiderman.jpg'),
('Figurina Iron Man', 'C', 'ironman.jpg');