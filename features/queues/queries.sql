select
	id,
	status,
	worker_id,
	processing_time,
	created_at,
	updated_at
from
	tasks
order by
	status,
	id
;
