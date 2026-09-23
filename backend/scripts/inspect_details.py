import asyncio
import json
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from app.database import get_session_factory, init_db
from sqlalchemy import select
from app.models.inspection import Inspection

async def check():
    await init_db()
    sf = get_session_factory()
    async with sf() as session:
        res = await session.execute(
            select(Inspection).where(Inspection.image_filename.like("%02_balaji%"))
        )
        insp = res.scalars().first()
        if insp:
            print(f"=== {insp.image_filename} ===")
            raw_ocr = json.loads(insp.raw_ocr_json) if insp.raw_ocr_json else []
            print(f"Raw OCR entries ({len(raw_ocr)}):")
            for r in raw_ocr:
                print(f"  [{r.get('confidence'):.2f}]: {r.get('text')}")
            decls = json.loads(insp.declarations_json) if insp.declarations_json else []
            for d in decls:
                print(f"[{d['field_name']}]")
                print(f"  Detected: {d['detected']}, Compliant: {d['compliant']}")
                print(f"  Value: {d.get('value')}")
                print(f"  Violations: {d.get('violations')}")
                print(f"  Placement: compliant={d.get('placement_compliant')}, review={d.get('placement_review_required')}\n")

if __name__ == "__main__":
    asyncio.run(check())
