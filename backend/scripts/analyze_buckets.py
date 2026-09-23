import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

import asyncio
import json
from app.database import get_session_factory, init_db
from sqlalchemy import select
from app.models.inspection import Inspection

async def analyze():
    await init_db()
    sf = get_session_factory()
    async with sf() as session:
        res = await session.execute(select(Inspection).order_by(Inspection.image_filename.asc()))
        inspections = res.scalars().all()
        
        print(f"{'FILENAME':<45} | {'DET':<4} | {'VIOLATIONS SUMMARY'}")
        print("-" * 100)
        for insp in inspections:
            decls = json.loads(insp.declarations_json) if insp.declarations_json else []
            det = [d['field_name'] for d in decls if d.get('detected')]
            viols = []
            for d in decls:
                for v in d.get('violations', []):
                    viols.append(f"{d['field_name']}: {v[:40]}")
            print(f"{insp.image_filename:<45} | {len(det)}/8 | {', '.join(viols[:3])}")

if __name__ == "__main__":
    asyncio.run(analyze())
