from logging.config import fileConfig

from sqlalchemy import engine_from_config
from sqlalchemy import pool

from alembic import context

# Import the database URL and SQLAlchemy Base used by the Order Service
from app.database import DATABASE_URL, Base

# Import the Order model so SQLAlchemy registers the orders table
# with Base.metadata before Alembic examines the schema
from app.models import Order


# Alembic configuration object loaded from alembic.ini
config = context.config

# Use the same database connection URL as the Order Service.
# This overrides the placeholder sqlalchemy.url value in alembic.ini
# and keeps database credentials out of the Alembic configuration file.
config.set_main_option("sqlalchemy.url", DATABASE_URL)


# Configure Python logging using the settings in alembic.ini
if config.config_file_name is not None:
    fileConfig(config.config_file_name)


# Give Alembic access to the Order Service's SQLAlchemy schema.
# This allows Alembic to compare our models with the actual database
# when generating migrations.
target_metadata = Base.metadata


# Limit Alembic autogeneration to database objects owned by the Order Service.
# Other services may have tables in the same PostgreSQL database, but the
# Order Service must not generate migrations that modify or delete them.
def include_object(object, name, type_, reflected, compare_to):
    if type_ == "table":
        return name in {"orders", "alembic_version_order"}

    return True


def run_migrations_offline() -> None:
    """
    Run migrations without creating a live database connection.

    Alembic uses the configured database URL to generate SQL rather
    than executing the migration directly against PostgreSQL.
    """

    url = config.get_main_option("sqlalchemy.url")

    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        include_object=include_object,

        # Order Service maintains its own migration history.
        # This prevents conflicts with the Product Service migrations
        # even though both currently share the same PostgreSQL database.
        version_table="alembic_version_order",
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """
    Run migrations using a live connection to PostgreSQL.

    This is the mode used by commands such as:
        alembic upgrade head
        alembic revision --autogenerate
    """

    # Build a SQLAlchemy engine using the database URL supplied
    # by the Order Service configuration.
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    # Open a database connection and give it to Alembic.
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,

            # Keep Order Service migration state separate from
            # migration state owned by the Product Service.
            version_table="alembic_version_order",
            include_object=include_object,
        )

        # Run all pending migrations inside a transaction.
        with context.begin_transaction():
            context.run_migrations()


# Alembic determines which migration mode was requested and
# executes the appropriate function.
if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()