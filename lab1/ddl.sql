CREATE TYPE user_role AS ENUM ('guest', 'host', 'both');


create table if not exists users (
    id serial primary key,
    name varchar(255) not null,
    email varchar(255) unique not null,
    password_hash varchar(255) not null, 
    phone varchar(20) unique,
    role user_role not null
);

create table if not exists estate (
    id serial primary key,
    host_id int not null,
    name varchar(255) not null,
    description text,
    location varchar(255) not null,
    price_per_night numeric(10, 2) not null,
    available_from date not null,
    available_to date not null,
    created_at timestamp default current_timestamp,
    foreign key (host_id) references users(id) on delete cascade
);

create table if not exists bookings (
    id serial primary key,
    estate_id int not null,
    guest_id int not null,
    start_date date not null,
    end_date date not null,
    total_price numeric(10, 2) not null,
    created_at timestamp default current_timestamp,
    foreign key (estate_id) references estate(id) on delete cascade,
    foreign key (guest_id) references users(id) on delete cascade
);

create table if not exists reviews (
    id serial primary key,
    booking_id int not null,
    rating int check (rating >= 1 and rating <= 5),
    comment text,
    created_at timestamp default current_timestamp,
    foreign key (booking_id) references bookings(id) on delete cascade
);