from .bookings import router as bookings_router
from .estates import router as estates_router
from .functions import router as functions_router
from .procedures import router as procedures_router
from .reports import router as reports_router
from .system import router as system_router
from .users import router as users_router
from .views import router as views_router

routers = [
    system_router,
    users_router,
    estates_router,
    bookings_router,
    views_router,
    functions_router,
    procedures_router,
    reports_router,
]
