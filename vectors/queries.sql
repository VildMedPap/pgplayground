-- check if the pgvector extension is installed in the database
select
	*
from
	pg_extension
where
	extname = 'vector';

-- verify that the vector data type exists in postgresql
select
	typname,
	typtype
from
	pg_type
where
	typname = 'vector';

-- test if we can create and cast to a vector type (basic functionality test)
select '[1,2,3]'::vector;

-- examine the structure of our embeddings table (dbeaver compatible version)
select
	column_name,
	data_type,
	character_maximum_length,
	is_nullable
from
	information_schema.columns
where
	table_name = 'embeddings'
order by
	ordinal_position;

-- test vector operations by calculating the euclidean distance between two vectors
select '[1,2,3]'::vector <-> '[4,5,6]'::vector as distance;

-- check if our index on the vector column was created properly
select
	indexname,
	indexdef
from
	pg_indexes
where
	tablename = 'embeddings';

-- test the cosine similarity function with various examples

-- 1. identical vectors should have cosine similarity of 1.0
select cosine_similarity('[1,0,0]'::vector, '[1,0,0]'::vector) as identical_vectors;

-- 2. orthogonal vectors should have cosine similarity of 0.0
select cosine_similarity('[1,0,0]'::vector, '[0,1,0]'::vector) as orthogonal_vectors;

-- 3. opposite vectors should have cosine similarity of -1.0
select cosine_similarity('[1,0,0]'::vector, '[-1,0,0]'::vector) as opposite_vectors;

-- 4. vectors at 45 degrees should have cosine similarity of approximately 0.7071
select cosine_similarity('[1,0,0]'::vector, '[1,1,0]'::vector) as vectors_45_degrees;

-- 5. vectors at 60 degrees should have cosine similarity of 0.5
select cosine_similarity('[1,0,0]'::vector, '[0.5,0.866,0]'::vector) as vectors_60_degrees;

-- 6. vectors at 90 degrees should have cosine similarity of 0.0
select cosine_similarity('[1,0,0]'::vector, '[0,1,0]'::vector) as vectors_90_degrees;

-- 7. vectors at 120 degrees should have cosine similarity of -0.5
select cosine_similarity('[1,0,0]'::vector, '[-0.5,0.866,0]'::vector) as vectors_120_degrees;

-- 8. vectors at 180 degrees should have cosine similarity of -1.0
select cosine_similarity('[1,0,0]'::vector, '[-1,0,0]'::vector) as vectors_180_degrees;

-- see content of embeddings
select * from embeddings limit 5;

-- give it a spin
-- get a specific vector from the table (for example, the first one)
with target_vector as (
	select embedding from embeddings where id = 1
)
-- find the 10 most similar vectors
select
	e.id,
	e.embedding_id,
	cosine_similarity(e.embedding, (select embedding from target_vector)) as similarity
from
	embeddings e
where
	-- exclude the target vector itself
	e.id != 1
order by
	similarity desc
limit 10;

-- real data
with target_vector as (
	select '[0.039409,...,0.064739]'::vector as embedding
)
select
	e.id,
	e.embedding_id,
	1 - (e.embedding <=> (
	select
		embedding
	from
		target_vector)) as similarity
from
	embeddings e
where
	1 - (e.embedding <=> (
	select
		embedding
	from
		target_vector)) >= 0.95
order by
	similarity desc;
