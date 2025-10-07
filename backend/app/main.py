from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List

from .database import Base, engine, AsyncSessionLocal
from .models import Item
from .schemas import ItemCreate, ItemUpdate, ItemOut


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Create tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # Shutdown: Clean up if needed
    await engine.dispose()


app = FastAPI(title="FastAPI CRUD", lifespan=lifespan)

# (Optional) Allow CORS during dev
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Dependency: DB session per request
async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/items", response_model=List[ItemOut])
async def list_items(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Item).order_by(Item.id.desc()))
    return result.scalars().all()


@app.post("/items", response_model=ItemOut)
async def create_item(payload: ItemCreate, db: AsyncSession = Depends(get_db)):
    item = Item(title=payload.title, description=payload.description)
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item


@app.put("/items/{item_id}", response_model=ItemOut)
async def update_item(item_id: int, payload: ItemUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Item).where(Item.id == item_id))
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    item.title = payload.title
    item.description = payload.description
    await db.commit()
    await db.refresh(item)
    return item


@app.delete("/items/{item_id}")
async def delete_item(item_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Item).where(Item.id == item_id))
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    await db.delete(item)
    await db.commit()
    return {"ok": True}