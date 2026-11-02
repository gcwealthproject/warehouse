import os
import pandas as pd
import re

# === MAIN PATHS ===
base_path = "C:/Users/franc/Dropbox/gcwealth/raw_data/taxw/sources/Final_Data_v2.0"
dictionary_path = "dictionary.xlsx"  # adjust if needed

# === LOAD COUNTRY CODES FROM DICTIONARY ===
geo_df = pd.read_excel("C:/Users/franc/Dropbox/gcwealth/handmade_tables/dictionary.xlsx", sheet_name="GEO") # adjust if needed

country_codes = geo_df["GEO"] 


# === TEXT CLEANING FUNCTION ===
def clean_note(text):
    if pd.isna(text):
        return text

    # --- 1. Fix common typos ---
    corrections = {
        "indipendence": "independence",
        "whith": "with",
        "succesion": "succession",
        "neices": "nieces",
        "nephwes": "nephews",
        "inhertiance": "inheritance",
        "Repulic": "Republic",
        "receipent": "recipient",
        "assests": "assets",
        "decendents": "descendants",
        "decendants": "descendants",
        "moe": "more",
        "multipier": "multiplier",
        "tne": "the",
        "thhe": "the",
        "fo ": "for ",
        "RED$": "RD$",
    }

    for wrong, correct in corrections.items():
        text = text.replace(wrong, correct)

    # --- 2. Fix missing spaces in patterns like "Tax for Xbecause" ---
    text = re.sub(r"(Tax for [A-Za-z ]+?)because", r"\1 because", text)

    # --- 3. Fix "noGift Tax" → "no Gift Tax" pattern ---
    text = re.sub(r"no([A-Z])", r"no \1", text)

    # --- 4. Remove duplicated punctuation ---
    text = re.sub(r"\.\.", ".", text)

    # --- 5. Ensure space after period ---
    text = re.sub(r"\.(\w)", r". \1", text)

    # --- 6. Trim and capitalize first letter ---
    text = text.strip()
    if len(text) > 0:
        text = text[0].upper() + text[1:]

    # --- 7. Fix simple grammar issues ---
    text = text.replace("children is", "child is")
    text = text.replace("must had", "must have")

    return text


# === LOOP THROUGH ALL COUNTRIES ===
for code in country_codes:
    folder_path = os.path.join(base_path, str(code))
    file_path = os.path.join(folder_path, f"Final_{code}.xlsx")

    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        continue

    try:
        df = pd.read_excel(file_path, engine="openpyxl")

        # --- Check if 'note' column exists ---
        if "note" not in df.columns:
            print(f"No 'note' column in {file_path}")
            continue

        # --- Apply cleaning function ---
        df["note"] = df["note"].apply(clean_note)

        # --- Overwrite original file with sheet name "Data" ---
        df.to_excel(file_path, index=False, engine="openpyxl", sheet_name="Data")

        print(f"✔ Processed: {file_path}")

    except Exception as e:
        print(f"Error in {file_path}: {e}")

print("✅ PROCESS COMPLETED")