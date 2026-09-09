
/*
members(member_id PK, name, email, city, membership_date)

authors(author_id PK, name, country)

books(book_id PK, title, author_id FK -> authors, genre, published_year, total_copies)

loans(loan_id PK, member_id FK -> members, book_id FK -> books,
      loan_date, due_date, return_date)  -- return_date NULL if not yet returned

fines(fine_id PK, loan_id FK -> loans, amount, paid_status)  -- paid_status: 'paid','unpaid'

reviews(review_id PK, book_id FK -> books, member_id FK -> members, rating, review_date)

staff(staff_id PK, name, role, branch_city)
*/
-- Relationships: one author → many books; one member → many loans; one book → many loans (over time) & many reviews; one loan → at most one fine (if returned late or lost).


-- 1. Find the top 3 members by total fines paid.

select m.member_id, m.name, sum(f.amount) as total_fines
from members m
join loans l on l.member_id = m.member_id
join fines f on f.loan_id = l.loan_id
where f.status = "paid"
group by m.member_id, m.name
order by total_fines desc
limit 3;


-- 2. For each genre, find the most-loaned book (by loan count).

with loans_per_genre as (
    select b.book_id, b.title, b.genre, count(*) as loan_count
    from books b
    join loans l on l.book_id = b.book_id
    group by b.book_id, b.title, b.genre
), ranked as (
    select *, rank() over (partition by genre order by loan_count) as rnk
    from loans_per_genre
)
select * from ranked
where rnk = 1;

-- 3. Find members who have borrowed a book from every genre available in the library.
-- 4. Find books that have never been loaned.
-- 5. Calculate each member's running count of books borrowed over time, ordered by loan date.
-- 6. Find the second most prolific author in each country (by number of books published), without using LIMIT/OFFSET.
-- 7. Identify members whose average loan duration (return_date − loan_date) is more than the overall average loan duration.
-- 8. Find the month-over-month percentage change in number of new loans issued.
-- 9. Find books with an average rating below 3 but more than 8 reviews.
-- 10. Find pairs of authors whose books are frequently borrowed by the same member (i.e., a member has loaned books from both authors), ordered by frequency.
