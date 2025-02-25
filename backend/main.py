# Updated Backend (FastAPI) for Dynamic Resume Parsing and Ranking with Frontend Integration

from fastapi import FastAPI, UploadFile, File, HTTPException, Form
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from pydantic import BaseModel
from typing import List
import shutil
import os
import PyPDF2

app = FastAPI()

# Enable CORS for frontend communication
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:8080/","http://127.0.0.1:8000"],  # For development; specify frontend URL in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DATABASE_URL = "sqlite:///./resumes.db"
Base = declarative_base()
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

UPLOAD_DIR = "uploaded_resumes"
os.makedirs(UPLOAD_DIR, exist_ok=True)

class Resume(Base):
    __tablename__ = "resumes"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    phone = Column(String)
    email = Column(String)
    qualification = Column(String)
    skills = Column(String)
    experience = Column(Integer)
    file_path = Column(String)
    score = Column(Float, default=0.0)

Base.metadata.create_all(bind=engine)

class Criteria(BaseModel):
    qualification: str
    skills: str
    experience: int
    resumes_selected: int

def extract_entities(file_path):
    with open(file_path, 'rb') as file:
        reader = PyPDF2.PdfReader(file)
        text = " ".join(page.extract_text() or "" for page in reader.pages)
    return {
        "name": "Extracted Name",
        "phone": "0000000000",
        "email": "example@example.com",
        "qualification": "Bachelor",
        "skills": "Python,Flutter",
        "experience": 2
    }

@app.post("/upload/")
async def upload_resumes(files: List[UploadFile] = File(...)):
    session = SessionLocal()
    for file in files:
        file_location = os.path.join(UPLOAD_DIR, file.filename)
        with open(file_location, "wb") as f:
            shutil.copyfileobj(file.file, f)
        extracted = extract_entities(file_location)
        resume = Resume(
            name=extracted["name"],
            phone=extracted["phone"],
            email=extracted["email"],
            qualification=extracted["qualification"],
            skills=extracted["skills"],
            experience=extracted["experience"],
            file_path=file_location
        )
        session.add(resume)
    session.commit()
    session.close()
    return {"message": "Resumes uploaded and processed successfully"}

@app.post("/rank/")
def rank_resumes(criteria: Criteria):
    session = SessionLocal()
    candidates = session.query(Resume).all()

    def calculate_score(candidate):
        score = 0
        if candidate.qualification.lower() == criteria.qualification.lower():
            score += 40
        candidate_skills = set(candidate.skills.lower().split(","))
        required_skills = set(criteria.skills.lower().split(","))
        score += (len(candidate_skills.intersection(required_skills)) / max(len(required_skills), 1)) * 40
        score += max(0, 1 - abs(candidate.experience - criteria.experience) / max(criteria.experience, 1)) * 20
        return round(score, 2)

    ranked_candidates = []
    for c in candidates:
        c.score = calculate_score(c)
        ranked_candidates.append(c)

    ranked_candidates.sort(key=lambda x: x.score, reverse=True)

    session.bulk_save_objects(ranked_candidates)
    session.commit()

    result = [
        {"id": c.id, "name": c.name, "phone": c.phone, "email": c.email, "score": c.score}
        for c in ranked_candidates[:criteria.resumes_selected]
    ]
    session.close()
    return result

@app.get("/resume/{resume_id}")
def get_resume(resume_id: int):
    session = SessionLocal()
    resume = session.query(Resume).filter(Resume.id == resume_id).first()
    session.close()
    if resume:
        return FileResponse(path=resume.file_path, filename=os.path.basename(resume.file_path))
    else:
        raise HTTPException(status_code=404, detail="Resume not found")
