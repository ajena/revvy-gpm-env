CREATE TABLE products (
    id BIGSERIAL,
    price INTEGER,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);

CREATE TABLE books (
    isbn TEXT,
    author TEXT,
    title TEXT
) INHERITS (products);

CREATE TABLE albums (
    artist TEXT,
    length INTEGER,
    number_of_songs INTEGER
) INHERITS (products);

INSERT INTO products values(1, 100, '2010-01-01', '2010-01-01');
INSERT INTO books values(2, 150, '2011-01-01', '2011-01-01', 'ISBN-001', 'Henry Wright', 'What a Joke!');
INSERT INTO albums values(3, 200, '2012-01-01', '2012-01-01', 'Jennifer Lopez', 35, 9);

INSERT INTO albums(artist, length, number_of_songs) values('JL', 36, 10);
INSERT INTO books(isbn, author, title) values('ISBN-002', 'Henry Wright''s Wife', 'What a Joke 2!');

SELECT * FROM ONLY products;
SELECT * FROM products;
SELECT * FROM books;
SELECT * FROM albums;

delete from albums;

ALTER TABLE albums NO INHERIT products;