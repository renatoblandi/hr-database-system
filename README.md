# HR Database System

This repo shows the design and SQL work from a relational database capstone project at Red River
College Polytechnic. It is not a running app, just the schema, the diagram, and the query work.
Shared here with permission from the course instructor.

## Skills and tools

- **SQL** (**MariaDB**)
- **Relational database design** and normalization
- **Recursive CTEs**
- **Views**
- **Nested and correlated subqueries**
- **Self joins**
- **Entity relationship diagramming** (draw.io)

## Scenario

The assignment was to design a database for a government agency's HR system: departments,
divisions, positions, employees, unions, and pay scales. Groups picked their own difficulty level
for the project. My team picked the hardest one offered.

Main business rules the schema had to support:

- An employee can hold many positions over their career, but only one at a time.
- Positions, not people, report to other positions, so the org chart still works after promotions
  and staff changes.
- Pay comes from a position's pay scale, which goes up with years of continuous service, and pay
  scales themselves change over time.
- Continuous service inside a union resets if an employee moves to a different union or leaves
  union coverage.

## My role

This was a team project. The schema, the entity relationship diagram, and the sample data were
designed together with my group. The query challenges in `query_challenges.sql` are my own
individual work: business questions solved against our schema, followed by a live technical
defense where the instructor asked follow up questions about the queries on the spot, without
notes.

## Entity relationship diagram

![ERD](c:\Users\renato\Pictures\Screenshots\database_ERD.png)

## Schema notes

- `employment_history` keeps every position an employee has ever held, with an open `end_date`
  marking their current one, so nothing gets overwritten.
- `pay_rules` tracks each position's pay scale by minimum years of service and by date range, so
  past pay can be worked out exactly as it was at the time.
- Two views, `current_salaries` and `historical_salaries`, hold the pay calculation logic in one
  place instead of repeating it in every query that needs it.

## Query challenges

`query_challenges.sql` has nine business questions solved against this schema, using recursive
CTEs, correlated subqueries, self joins, and grouping with filters.

## Running it locally

```sql
mysql -u root -p < database_creation.sql
mysql -u root -p capstone < query_challenges.sql
```
