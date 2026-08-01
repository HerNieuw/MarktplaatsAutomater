#!/bin/bash
# ================================================
# Marktplaats Automatisering - GTK Versie
# Installeert alle benodigde componenten en maakt
# een applicatie-snelkoppeling met logo
# ================================================

set -e  # Stop bij fouten

# Kleuren voor output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     MARKTPLAATS AUTOMATISERING - GTK INSTALLATIE        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ================================================
# STAP 1: Systeem updates
# ================================================
echo -e "${YELLOW}📦 Stap 1: Systeem bijwerken...${NC}"
sudo apt update -y
sudo apt upgrade -y
echo -e "${GREEN}✅ Systeem bijgewerkt${NC}"
echo ""

# ================================================
# STAP 2: Python en GTK installeren
# ================================================
echo -e "${YELLOW}🐍 Stap 2: Python, GTK en afhankelijkheden installeren...${NC}"
sudo apt install -y python3 python3-pip python3-venv \
    python3-gi python3-gi-cairo gir1.2-gtk-3.0 \
    gir1.2-gdkpixbuf-2.0 gir1.2-pango-1.0 \
    gir1.2-glib-2.0
echo -e "${GREEN}✅ Python en GTK geïnstalleerd${NC}"
echo ""

# ================================================
# STAP 3: Chrome browser installeren
# ================================================
echo -e "${YELLOW}🌐 Stap 3: Chrome browser installeren...${NC}"
if command -v google-chrome &> /dev/null; then
    echo -e "${GREEN}✅ Chrome is al geïnstalleerd${NC}"
else
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
    sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
    sudo apt update -y
    sudo apt install -y google-chrome-stable
    echo -e "${GREEN}✅ Chrome geïnstalleerd${NC}"
fi
echo ""

# ================================================
# STAP 4: Chromedriver installeren
# ================================================
echo -e "${YELLOW}🚗 Stap 4: Chromedriver installeren...${NC}"
if command -v chromedriver &> /dev/null; then
    echo -e "${GREEN}✅ Chromedriver is al geïnstalleerd${NC}"
else
    sudo apt install -y chromium-chromedriver
    echo -e "${GREEN}✅ Chromedriver geïnstalleerd${NC}"
fi
echo ""

# ================================================
# STAP 5: Python packages installeren
# ================================================
echo -e "${YELLOW}📚 Stap 5: Python packages installeren...${NC}"

# Maak MarktplaatsAutomater map aan
mkdir -p "MarktplaatsAutomater"

# Maak virtuele omgeving aan in de juiste map
if [ ! -d "MarktplaatsAutomater/venv" ]; then
    echo -e "${BLUE}   Virtuele omgeving aanmaken...${NC}"
    python3 -m venv MarktplaatsAutomater/venv
    echo -e "${GREEN}   ✅ Virtuele omgeving aangemaakt${NC}"
else
    echo -e "${BLUE}   ✅ Virtuele omgeving bestaat al${NC}"
fi

# Activeer virtuele omgeving en installeer packages
source MarktplaatsAutomater/venv/bin/activate

pip install --upgrade pip
# pygobject wordt NIET via pip geïnstalleerd - we gebruiken de systeem versie!
pip install selenium gspread google-auth pandas requests pillow

echo -e "${GREEN}✅ Alle Python packages geïnstalleerd${NC}"
echo ""

# ================================================
# STAP 6: Logo downloaden
# ================================================
echo -e "${YELLOW}🖼️  Stap 6: Logo downloaden...${NC}"

if [ -f "logo.png" ]; then
    cp logo.png "MarktplaatsAutomater/logo.png"
    echo -e "${GREEN}✅ Logo gekopieerd${NC}"
else
    # Maak een eenvoudig logo met Python
    python3 -c "
from PIL import Image, ImageDraw
import os

# Maak een 256x256 logo
img = Image.new('RGB', (256, 256), color='#4285F4')
draw = ImageDraw.Draw(img)

# Teken een 'M' als logo
draw.rectangle([40, 40, 216, 216], fill='#FFFFFF', outline='#FFFFFF', width=5)
draw.text((80, 80), 'M', fill='#4285F4', font=None)
draw.text((100, 160), 'P', fill='#4285F4', font=None)

# Teken een winkelwagentje
draw.rectangle([60, 180, 196, 210], fill='#FFFFFF')
draw.rectangle([80, 150, 100, 180], fill='#FFFFFF')

# Opslaan
img.save('MarktplaatsAutomater/logo.png')
print('✅ Logo aangemaakt')
"
    echo -e "${GREEN}✅ Logo aangemaakt${NC}"
fi
echo ""

# ================================================
# STAP 7: Het GTK script aanmaken
# ================================================
echo -e "${YELLOW}📝 Stap 7: marktplaats_automater_gtk.py aanmaken...${NC}"

cat > MarktplaatsAutomater/marktplaats_automater_gtk.py << 'EOF'
#!/usr/bin/env python3
"""
Marktplaats Automatisering - GTK Versie
Alle instellingen binnen de GUI
"""

import os
import sys
import time
import threading
import re
import json
import subprocess
from pathlib import Path

# GTK imports - deze komen van de systeem packages (python3-gi)
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
gi.require_version('Pango', '1.0')
from gi.repository import Gtk, Gdk, Pango, GLib, GdkPixbuf

# Probeer selenium te importeren
try:
    from selenium import webdriver
    from selenium.webdriver.chrome.options import Options
    from selenium.webdriver.common.by import By
    from selenium.webdriver.common.keys import Keys
    from selenium.webdriver.common.action_chains import ActionChains
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
except ImportError as e:
    print(f"❌ Fout: {e}")
    print("📌 Installeer selenium met: pip install selenium")
    sys.exit(1)

# Probeer gspread te importeren
try:
    import gspread
    from google.oauth2.service_account import Credentials
except ImportError as e:
    print(f"❌ Fout: {e}")
    print("📌 Installeer gspread met: pip install gspread google-auth")
    sys.exit(1)

# ============================================
# CONFIGURATIE BESTAND
# ============================================

class ConfigManager:
    def __init__(self, config_file="config.json"):
        self.config_file = config_file
        self.config = self._load()
    
    def _load(self):
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r') as f:
                    return json.load(f)
            except:
                return self._default_config()
        return self._default_config()
    
    def _default_config(self):
        return {
            "chrome": {
                "user_data_dir": os.path.expanduser("~/.config/google-chrome"),
                "profile": "Default"
            },
            "google_sheets": {
                "sheet_url": "",
                "credentials_file": "credentials.json"
            },
            "paths": {
                "base_image_path": os.path.expanduser("~/Afbeeldingen")
            },
            "preferences": {
                "max_title_length": 60,
                "wait_between_products": 3
            }
        }
    
    def save(self):
        try:
            with open(self.config_file, 'w') as f:
                json.dump(self.config, f, indent=2)
            return True
        except Exception as e:
            print(f"Fout bij opslaan: {e}")
            return False
    
    def get(self, key, default=None):
        keys = key.split('.')
        value = self.config
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default
        return value
    
    def set(self, key, value):
        keys = key.split('.')
        target = self.config
        for k in keys[:-1]:
            if k not in target:
                target[k] = {}
            target = target[k]
        target[keys[-1]] = value
        self.save()

# ============================================
# LOGGING
# ============================================

class Logger:
    def __init__(self, text_view=None):
        self.text_view = text_view
        self.buffer = None
        if text_view:
            self.buffer = text_view.get_buffer()
    
    def log(self, msg, level="INFO"):
        timestamp = time.strftime("%H:%M:%S")
        formatted = f"[{timestamp}] {level}: {msg}\n"
        if self.buffer:
            end_iter = self.buffer.get_end_iter()
            self.buffer.insert(end_iter, formatted)
            mark = self.buffer.create_mark(None, self.buffer.get_end_iter(), False)
            self.text_view.scroll_to_mark(mark, 0.0, True, 0.0, 0.0)
        print(formatted, end="")
        while Gtk.events_pending():
            Gtk.main_iteration()
    
    def info(self, msg): self.log(msg, "INFO")
    def warning(self, msg): self.log(msg, "⚠️")
    def error(self, msg): self.log(msg, "❌")
    def success(self, msg): self.log(f"✅ {msg}", "SUCCESS")
    def step(self, num, msg): self.log(f"📍 Stap {num}: {msg}", "STEP")

# ============================================
# ALGEMENE VOORWAARDEN
# ============================================

ALGEMENE_VOORWAARDEN = """Algemene voorwaarden: 
Wij zijn een kleine kringloopwinkel en proberen z.s.m. te reageren. Soms is het heel druk in de winkel en lukt dit niet dezelfde dag. 

De richtprijs van een product baseren wij op bestaand aanbod en staat van het artikel met minimum/maximum schatting. 

Graag alleen biedingen plaatsen via de bied optie van marktplaats. Advertenties laten we vaak minimaal 2 weken online staan voordat we akkoord gaan met het hoogste aannemelijke bod. Bedankt voor uw begrip 🙏🏻 

Als wij akkoord gaan met uw bod, reserveren wij het product maximaal een week voor u. U kunt het product ophalen en afrekenen in onze winkel.

U bent altijd welkom in onze winkel, maar langskomen voor de Marktplaats advertenties zonder afspraak wordt niet op prijs gesteld. Dit gaat altijd via specifieke medewerkers. 

Let op: Bij ophalen in de winkel vervalt het herroepingsrecht en kun je het product ter plekke testen. 

Ons adres:
Kringloop HerNieuw 
Willem Beukelszstraat 6B 
3261 LV Oud-Beijerland

Openingstijden Kringloop: 
Dinsdag t/m vrijdag 10.00 – 16.00 uur 
Zaterdag 10:00-13:00 uur 
Zondag en maandag Gesloten"""

def build_description(product):
    row = product.get("row", [])
    def col(idx):
        return row[idx].strip() if len(row) > idx and row[idx] else ""
    
    titel = product.get("titel", "")
    artikelnummer = col(0)
    omschrijving = col(3)
    lengte = col(5)
    breedte = col(6)
    hoogte = col(7)
    gewicht = col(8)
    conditie = col(9)
    schades = col(10)
    waarde = col(11)
    waarde_extra = col(12)
    voorwaarden = col(23)
    
    parts = []
    if titel:
        parts.append(titel)
    if omschrijving:
        parts.append(omschrijving)
    
    specs = []
    if lengte or breedte or hoogte or gewicht:
        dims = [f"{x}cm" for x in (lengte, breedte, hoogte) if x]
        line = f"* Afmeting (LxBxH & G): {' x '.join(dims)}"
        if gewicht:
            line += f" & {gewicht} kg"
        specs.append(line)
    if conditie:
        specs.append(f"* Conditie/Staat: {conditie}")
    if schades:
        specs.append(f"* Schades: {schades}")
    if waarde:
        line = f"* Waarde: {waarde}"
        if waarde_extra:
            line += f" ~{waarde_extra}"
        specs.append(line)
    if artikelnummer:
        specs.append(f"* Artikelnummer: {artikelnummer}")
    if specs:
        parts.append("\n".join(specs))
    
    parts.append(voorwaarden if voorwaarden else ALGEMENE_VOORWAARDEN)
    return "\n\n".join(parts)

# ============================================
# MARKTPLAATS AUTOMATOR
# ============================================

class MarktplaatsAuto:
    def __init__(self, config, logger):
        self.config = config
        self.logger = logger
        self.driver = None
        self.wait = None
        self.running = False
        self.products = []
        self.pending = []
        self.current = None
        self.step = 0
        self.wait_for_user = False
        self.was_skipped = False
        self.on_wait_for_user = None
        self.user_logged_in = False
    
    def start_chrome(self):
        self.logger.info("🚀 Start Chrome...")
        options = Options()
        chrome_config = self.config.get('chrome', {})
        user_data_dir = chrome_config.get('user_data_dir', os.path.expanduser("~/.config/google-chrome"))
        profile = chrome_config.get('profile', "Default")
        
        options.add_argument(f"--user-data-dir={user_data_dir}")
        options.add_argument(f"--profile-directory={profile}")
        options.add_argument("--disable-blink-features=AutomationControlled")
        options.add_experimental_option("excludeSwitches", ["enable-automation"])
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--disable-gpu')
        options.add_argument('--window-size=1920,1080')
        
        try:
            self.driver = webdriver.Chrome(options=options)
            self.wait = WebDriverWait(self.driver, 15)
            self.logger.success("Chrome gestart!")
            return True
        except Exception as e:
            self.logger.error(f"Chrome fout: {e}")
            self.logger.info("💡 Zorg dat Chrome niet open staat en probeer opnieuw")
            return False
    
    def wait_for_manual_login(self):
        self.logger.info("=" * 50)
        self.logger.info("🔑 LOG IN OP MARKTPLAATS")
        self.logger.info("=" * 50)
        self.logger.info("📌 Open de browser en log handmatig in op Marktplaats")
        self.logger.info("📌 Na het inloggen, klik op de knop 'Ingelogd' in de GUI")
        self.logger.info("=" * 50)
        
        self.driver.get("https://www.marktplaats.nl")
        time.sleep(2)
        
        while not self.user_logged_in and self.running:
            time.sleep(0.5)
        
        if not self.running:
            return False
        
        self.logger.success("✅ Gebruiker heeft ingelogd!")
        time.sleep(2)
        return True
    
    def load_products(self):
        self.logger.info("📊 Laden uit Google Sheets...")
        try:
            sheet_url = self.config.get('google_sheets.sheet_url', '')
            creds_file = self.config.get('google_sheets.credentials_file', 'credentials.json')
            
            if not sheet_url:
                self.logger.error("SHEET_URL niet ingesteld!")
                return False
            
            if not os.path.exists(creds_file):
                self.logger.error(f"credentials.json niet gevonden!")
                self.logger.info(f"📌 Plaats credentials.json in: {os.getcwd()}")
                return False
            
            scope = ["https://spreadsheets.google.com/feeds", 
                     "https://www.googleapis.com/auth/spreadsheets",
                     "https://www.googleapis.com/auth/drive"]
            creds = Credentials.from_service_account_file(creds_file, scopes=scope)
            client = gspread.authorize(creds)
            
            sheet = client.open_by_url(sheet_url)
            worksheet = sheet.get_worksheet(0)
            all_values = worksheet.get_all_values()
            
            hidden_rows = set()
            try:
                meta = sheet.fetch_sheet_metadata(
                    params={"fields": "sheets(properties(sheetId),data(rowMetadata(hiddenByUser)))"}
                )
                for s in meta.get("sheets", []):
                    if s["properties"]["sheetId"] == worksheet.id:
                        row_meta = s.get("data", [{}])[0].get("rowMetadata", [])
                        for i, rm in enumerate(row_meta):
                            if rm.get("hiddenByUser"):
                                hidden_rows.add(i + 1)
                        break
            except Exception as e:
                self.logger.warning(f"Kon verborgen-rij-metadata niet ophalen: {e}")
            
            rows = []
            for idx, row in enumerate(all_values[1:], start=2):
                if idx in hidden_rows:
                    continue
                if len(row) < 3:
                    continue
                
                artikelnummer = row[0].strip() if row[0] else ""
                titel = row[1].strip() if len(row) > 1 and row[1] else ""
                categorie = row[2].strip() if len(row) > 2 and row[2] else ""
                
                if artikelnummer and titel:
                    rows.append({
                        "rij": idx,
                        "artikelnummer": artikelnummer,
                        "titel": titel,
                        "categorie": categorie or titel,
                        "row": row
                    })
            
            self.products = rows
            self.pending = rows.copy()
            self.logger.info(f"✅ {len(rows)} producten geladen ({len(hidden_rows)} verborgen rijen overgeslagen)")
            return True
            
        except Exception as e:
            self.logger.error(f"Fout bij laden: {e}")
            return False
    
    def process_products(self):
        total = len(self.pending)
        processed = 0
        
        for product in self.pending:
            if not self.running:
                break
            
            processed += 1
            self.current = product
            self.logger.info(f"\n{'='*50}")
            self.logger.info(f"📦 Product {processed}/{total}: {product['artikelnummer']}")
            self.logger.info(f"📝 Titel: {product['titel']}")
            self.logger.info(f"{'='*50}")
            
            if not self.process_one_product(product):
                self.logger.warning(f"⏭️ Product {product['artikelnummer']} overgeslagen")
                continue
            
            if processed < total and self.running:
                wait_time = self.config.get('preferences.wait_between_products', 3)
                self.logger.info(f"⏳ Wacht {wait_time} seconden...")
                time.sleep(wait_time)
        
        if self.running:
            self.logger.success(f"🎉 Alle {processed} producten verwerkt!")
        else:
            self.logger.info(f"⏹️ Gestopt na {processed} producten")
    
    def process_one_product(self, product):
        try:
            self.step = 1
            self.logger.step(self.step, "Naar plaats pagina")
            self.driver.get("https://www.marktplaats.nl/plaats")
            time.sleep(2)
            
            self.step = 2
            self.logger.step(self.step, "Categorie invullen")
            max_len = self.config.get('preferences.max_title_length', 60)
            cat = product['categorie'][:max_len].strip()
            cat = re.sub(r'[^\x00-\x7F]+', '', cat)
            
            try:
                cat_field = self.driver.find_element(By.CSS_SELECTOR, 
                    "input[placeholder*='Categorie'], input[placeholder*='categorie']")
            except:
                cat_field = self.driver.find_element(By.CSS_SELECTOR, "input[name='keywords']")
            
            cat_field.clear()
            cat_field.send_keys(cat)
            time.sleep(0.3)
            cat_field.send_keys(Keys.ENTER)
            time.sleep(1)
            self.logger.info(f"   ✅ Categorie: {cat}")
            
            self.step = 3
            self.logger.step(self.step, "Titel invullen")
            title = product['titel'][:max_len].strip()
            title = re.sub(r'[^\x00-\x7F]+', '', title)
            
            title_field = self.wait.until(
                EC.presence_of_element_located((By.NAME, "keywords"))
            )
            title_field.clear()
            title_field.send_keys(title)
            time.sleep(0.3)
            title_field.send_keys(Keys.ENTER)
            time.sleep(1)
            
            actions = ActionChains(self.driver)
            for _ in range(4):
                actions.send_keys(Keys.TAB)
                time.sleep(0.2)
            actions.send_keys(Keys.ENTER).perform()
            time.sleep(2)
            self.logger.info(f"   ✅ Titel: {title}")
            
            self.step = 4
            self.logger.step(self.step, "Foto's uploaden")
            base_path = self.config.get('paths.base_image_path', os.path.expanduser("~/Afbeeldingen"))
            folder = os.path.join(base_path, product['artikelnummer'], "met_logo")
            images = []
            if os.path.exists(folder):
                for f in os.listdir(folder):
                    if f.lower().endswith(('.jpg', '.jpeg', '.png', '.gif', '.webp')):
                        images.append(os.path.join(folder, f))
            images.sort()
            
            if images:
                file_input = self.driver.find_element(By.CSS_SELECTOR, "input[type='file']")
                file_input.send_keys("\n".join(images[:10]))
                time.sleep(5)
                self.logger.info(f"   ✅ {len(images[:10])} foto's geüpload")
            else:
                self.logger.info("   ⚠️ Geen foto's gevonden")
            
            self.step = 5
            self.logger.step(self.step, "Omschrijving invullen")
            description = build_description(product)
            
            if description:
                try:
                    desc_field = self.wait.until(
                        EC.presence_of_element_located((
                            By.CSS_SELECTOR,
                            "div.RichTextEditor-module-editorInput[data-testid='text-editor-input_nl-NL']"
                        ))
                    )
                    desc_field.click()
                    time.sleep(0.3)
                    
                    for line in description.split("\n"):
                        if line.strip():
                            self.driver.execute_script(
                                "document.execCommand('insertText', false, arguments[0]);",
                                line
                            )
                        desc_field.send_keys(Keys.ENTER)
                        time.sleep(0.05)
                    
                    self.logger.info("   ✅ Omschrijving ingevuld")
                except Exception as e:
                    self.logger.warning(f"   ⚠️ Omschrijving invullen mislukt: {e}")
            else:
                self.logger.info("   ⚠️ Geen omschrijving-data gevonden, overgeslagen")
            
            self.step = 6
            self.logger.step(self.step, "Wacht op gebruiker")
            self.logger.info("")
            self.logger.info("📝 ADVERTENTIE IS BIJNA KLAAR!")
            self.logger.info("📝 Maak de advertentie handmatig af:")
            self.logger.info("   1. Controleer de beschrijving")
            self.logger.info("   2. Vul eventuele extra velden in")
            self.logger.info("   3. Klik op 'Plaats advertentie'")
            self.logger.info("")
            self.logger.info("⏸️ Klik op 'Volgende' als de advertentie geplaatst is, of 'Overslaan' om dit product bewust over te slaan")
            
            self.was_skipped = False
            self.wait_for_user = True
            if self.on_wait_for_user:
                self.on_wait_for_user()
            while self.wait_for_user and self.running:
                time.sleep(0.5)
            
            self.wait_for_user = False
            if self.was_skipped:
                self.logger.warning(f"⏭️ Product {product['artikelnummer']} bewust overgeslagen")
            else:
                self.logger.success(f"✅ Product {product['artikelnummer']} voltooid!")
            return True
            
        except Exception as e:
            self.logger.error(f"Fout bij product {product['artikelnummer']}: {e}")
            return False
    
    def go_to_next(self):
        self.wait_for_user = False
    
    def skip_current(self):
        self.was_skipped = True
        try:
            self.logger.info("⏭️ Overslaan - pagina verlaten...")
            self.driver.get("https://www.marktplaats.nl/plaats")
        except Exception as e:
            self.logger.warning(f"Kon niet terugkeren naar plaats-pagina: {e}")
        self.wait_for_user = False
    
    def stop(self):
        self.running = False
    
    def close(self):
        if self.driver:
            try:
                self.driver.quit()
            except:
                pass
            self.driver = None

# ============================================
# GTK GUI
# ============================================

class App:
    def __init__(self):
        # GTK zet automatisch de juiste WM_CLASS!
        self.window = Gtk.Window()
        self.window.set_title("Marktplaats Automatisering")
        self.window.set_default_size(1000, 750)
        self.window.set_position(Gtk.WindowPosition.CENTER)
        self.window.set_border_width(10)
        
        # Zet het icoon (als beschikbaar)
        try:
            icon_path = os.path.join(os.path.dirname(__file__), "logo.png")
            if os.path.exists(icon_path):
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_size(icon_path, 64, 64)
                self.window.set_icon(pixbuf)
        except:
            pass
        
        # Configuratie
        self.config = ConfigManager()
        self.logger = Logger()
        self.auto = MarktplaatsAuto(self.config, self.logger)
        self.auto.on_wait_for_user = self._on_wait_for_user
        self.running = False
        
        self._setup_ui()
        self._load_config_to_gui()
        
        self.logger.info("🚀 Klaar om te starten!")
        self.logger.info("📌 Vul eerst de instellingen in en klik op 'Opslaan'")
        
        self.window.connect("destroy", self._on_close)
    
    def _setup_ui(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.window.add(vbox)
        
        notebook = Gtk.Notebook()
        vbox.pack_start(notebook, True, True, 0)
        
        # ===== TAB 1: INSTELLINGEN =====
        settings_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        settings_box.set_border_width(10)
        notebook.append_page(settings_box, Gtk.Label(label="⚙️ Instellingen"))
        
        # Chrome profiel sectie
        label = Gtk.Label()
        label.set_markup("<b>Chrome Profiel</b>")
        label.set_halign(Gtk.Align.START)
        settings_box.pack_start(label, False, False, 0)
        
        grid = Gtk.Grid()
        grid.set_column_spacing(10)
        grid.set_row_spacing(5)
        grid.set_margin_bottom(10)
        settings_box.pack_start(grid, False, False, 0)
        
        label = Gtk.Label(label="Profiel pad:")
        label.set_halign(Gtk.Align.END)
        grid.attach(label, 0, 0, 1, 1)
        self.profile_path_entry = Gtk.Entry()
        self.profile_path_entry.set_hexpand(True)
        grid.attach(self.profile_path_entry, 1, 0, 1, 1)
        
        label = Gtk.Label(label="Profiel naam:")
        label.set_halign(Gtk.Align.END)
        grid.attach(label, 0, 1, 1, 1)
        self.profile_name_entry = Gtk.Entry()
        grid.attach(self.profile_name_entry, 1, 1, 1, 1)
        
        # Google Sheets sectie
        label = Gtk.Label()
        label.set_markup("<b>Google Sheets</b>")
        label.set_halign(Gtk.Align.START)
        label.set_margin_top(10)
        settings_box.pack_start(label, False, False, 0)
        
        grid = Gtk.Grid()
        grid.set_column_spacing(10)
        grid.set_row_spacing(5)
        grid.set_margin_bottom(10)
        settings_box.pack_start(grid, False, False, 0)
        
        label = Gtk.Label(label="Sheet URL:")
        label.set_halign(Gtk.Align.END)
        grid.attach(label, 0, 0, 1, 1)
        self.sheet_url_entry = Gtk.Entry()
        self.sheet_url_entry.set_hexpand(True)
        grid.attach(self.sheet_url_entry, 1, 0, 1, 1)
        
        label = Gtk.Label(label="Credentials.json:")
        label.set_halign(Gtk.Align.END)
        grid.attach(label, 0, 1, 1, 1)
        creds_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        self.creds_file_entry = Gtk.Entry()
        self.creds_file_entry.set_hexpand(True)
        creds_box.pack_start(self.creds_file_entry, True, True, 0)
        browse_btn = Gtk.Button(label="Bladeren")
        browse_btn.connect("clicked", self._browse_creds)
        creds_box.pack_start(browse_btn, False, False, 0)
        grid.attach(creds_box, 1, 1, 1, 1)
        
        # Paden sectie
        label = Gtk.Label()
        label.set_markup("<b>Paden</b>")
        label.set_halign(Gtk.Align.START)
        label.set_margin_top(10)
        settings_box.pack_start(label, False, False, 0)
        
        grid = Gtk.Grid()
        grid.set_column_spacing(10)
        grid.set_row_spacing(5)
        grid.set_margin_bottom(10)
        settings_box.pack_start(grid, False, False, 0)
        
        label = Gtk.Label(label="Afbeeldingen pad:")
        label.set_halign(Gtk.Align.END)
        grid.attach(label, 0, 0, 1, 1)
        path_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        self.image_path_entry = Gtk.Entry()
        self.image_path_entry.set_hexpand(True)
        path_box.pack_start(self.image_path_entry, True, True, 0)
        browse_path_btn = Gtk.Button(label="Bladeren")
        browse_path_btn.connect("clicked", self._browse_path)
        path_box.pack_start(browse_path_btn, False, False, 0)
        grid.attach(path_box, 1, 0, 1, 1)
        
        # Voorkeuren sectie
        label = Gtk.Label()
        label.set_markup("<b>Voorkeuren</b>")
        label.set_halign(Gtk.Align.START)
        label.set_margin_top(10)
        settings_box.pack_start(label, False, False, 0)
        
        grid = Gtk.Grid()
        grid.set_column_spacing(10)
        grid.set_row_spacing(5)
        settings_box.pack_start(grid, False, False, 0)
        
        label = Gtk.Label(label="Max titel lengte:")
        label.set_halign(Gtk.Align.END)
        grid.attach(label, 0, 0, 1, 1)
        self.max_title_entry = Gtk.Entry()
        self.max_title_entry.set_width_chars(10)
        grid.attach(self.max_title_entry, 1, 0, 1, 1)
        
        label = Gtk.Label(label="Wacht tussen producten (sec):")
        label.set_halign(Gtk.Align.END)
        grid.attach(label, 0, 1, 1, 1)
        self.wait_products_entry = Gtk.Entry()
        self.wait_products_entry.set_width_chars(10)
        grid.attach(self.wait_products_entry, 1, 1, 1, 1)
        
        save_btn = Gtk.Button(label="💾 Opslaan")
        save_btn.connect("clicked", self._save_config)
        settings_box.pack_start(save_btn, False, False, 0)
        
        # ===== TAB 2: DASHBOARD =====
        dashboard_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        dashboard_box.set_border_width(10)
        notebook.append_page(dashboard_box, Gtk.Label(label="🎮 Dashboard"))
        
        self.status_label = Gtk.Label()
        self.status_label.set_markup("<span foreground='green'>✅ Klaar</span>")
        dashboard_box.pack_start(self.status_label, False, False, 0)
        
        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        btn_box.set_halign(Gtk.Align.CENTER)
        dashboard_box.pack_start(btn_box, False, False, 0)
        
        self.start_btn = Gtk.Button(label="▶️ Start")
        self.start_btn.connect("clicked", self._start)
        btn_box.pack_start(self.start_btn, False, False, 0)
        
        self.login_btn = Gtk.Button(label="🔑 Ingelogd")
        self.login_btn.set_sensitive(False)
        self.login_btn.connect("clicked", self._logged_in)
        btn_box.pack_start(self.login_btn, False, False, 0)
        
        self.next_btn = Gtk.Button(label="⏭️ Volgende")
        self.next_btn.set_sensitive(False)
        self.next_btn.connect("clicked", self._next)
        btn_box.pack_start(self.next_btn, False, False, 0)
        
        self.skip_btn = Gtk.Button(label="⏩ Overslaan")
        self.skip_btn.set_sensitive(False)
        self.skip_btn.connect("clicked", self._skip)
        btn_box.pack_start(self.skip_btn, False, False, 0)
        
        self.stop_btn = Gtk.Button(label="⏹️ Stop")
        self.stop_btn.set_sensitive(False)
        self.stop_btn.connect("clicked", self._stop)
        btn_box.pack_start(self.stop_btn, False, False, 0)
        
        self.progress_bar = Gtk.ProgressBar()
        dashboard_box.pack_start(self.progress_bar, False, False, 0)
        self.progress_label = Gtk.Label(label="0%")
        dashboard_box.pack_start(self.progress_label, False, False, 0)
        
        # ===== TAB 3: LOG =====
        log_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        log_box.set_border_width(10)
        notebook.append_page(log_box, Gtk.Label(label="📝 Log"))
        
        log_btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        log_btn_box.set_halign(Gtk.Align.START)
        log_box.pack_start(log_btn_box, False, False, 0)
        
        clear_btn = Gtk.Button(label="🗑️ Wis log")
        clear_btn.connect("clicked", self._clear_log)
        log_btn_box.pack_start(clear_btn, False, False, 0)
        
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_vexpand(True)
        scrolled.set_hexpand(True)
        scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        log_box.pack_start(scrolled, True, True, 0)
        
        self.log_text_view = Gtk.TextView()
        self.log_text_view.set_editable(False)
        self.log_text_view.set_wrap_mode(Gtk.WrapMode.WORD)
        self.log_text_view.set_font(Pango.FontDescription("Monospace 9"))
        scrolled.add(self.log_text_view)
        
        self.logger = Logger(self.log_text_view)
        self.auto.logger = self.logger
    
    def _browse_creds(self, widget):
        dialog = Gtk.FileChooserDialog(
            title="Selecteer credentials.json",
            parent=self.window,
            action=Gtk.FileChooserAction.OPEN
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_OPEN, Gtk.ResponseType.OK
        )
        filter_json = Gtk.FileFilter()
        filter_json.set_name("JSON files")
        filter_json.add_pattern("*.json")
        dialog.add_filter(filter_json)
        
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            self.creds_file_entry.set_text(dialog.get_filename())
        dialog.destroy()
    
    def _browse_path(self, widget):
        dialog = Gtk.FileChooserDialog(
            title="Selecteer afbeeldingen map",
            parent=self.window,
            action=Gtk.FileChooserAction.SELECT_FOLDER
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_OPEN, Gtk.ResponseType.OK
        )
        
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            self.image_path_entry.set_text(dialog.get_filename())
        dialog.destroy()
    
    def _load_config_to_gui(self):
        chrome = self.config.get('chrome', {})
        self.profile_path_entry.set_text(chrome.get('user_data_dir', os.path.expanduser("~/.config/google-chrome")))
        self.profile_name_entry.set_text(chrome.get('profile', "Default"))
        
        gs = self.config.get('google_sheets', {})
        self.sheet_url_entry.set_text(gs.get('sheet_url', ''))
        self.creds_file_entry.set_text(gs.get('credentials_file', 'credentials.json'))
        
        paths = self.config.get('paths', {})
        self.image_path_entry.set_text(paths.get('base_image_path', os.path.expanduser("~/Afbeeldingen")))
        
        prefs = self.config.get('preferences', {})
        self.max_title_entry.set_text(str(prefs.get('max_title_length', 60)))
        self.wait_products_entry.set_text(str(prefs.get('wait_between_products', 3)))
    
    def _save_config(self, widget):
        self.config.set('chrome.user_data_dir', self.profile_path_entry.get_text().strip())
        self.config.set('chrome.profile', self.profile_name_entry.get_text().strip())
        self.config.set('google_sheets.sheet_url', self.sheet_url_entry.get_text().strip())
        self.config.set('google_sheets.credentials_file', self.creds_file_entry.get_text().strip())
        self.config.set('paths.base_image_path', self.image_path_entry.get_text().strip())
        self.config.set('preferences.max_title_length', int(self.max_title_entry.get_text().strip() or 60))
        self.config.set('preferences.wait_between_products', int(self.wait_products_entry.get_text().strip() or 3))
        
        self.logger.success("✅ Configuratie opgeslagen!")
        
        dialog = Gtk.MessageDialog(
            parent=self.window,
            flags=0,
            message_type=Gtk.MessageType.INFO,
            buttons=Gtk.ButtonsType.OK,
            text="Configuratie opgeslagen!"
        )
        dialog.run()
        dialog.destroy()
    
    def _start(self, widget):
        if self.running:
            return
        
        self._save_config(widget)
        
        self.running = True
        self.auto.running = True
        self.auto.user_logged_in = False
        self.start_btn.set_sensitive(False)
        self.login_btn.set_sensitive(True)
        self.stop_btn.set_sensitive(True)
        self.next_btn.set_sensitive(False)
        self.skip_btn.set_sensitive(False)
        self.status_label.set_markup("<span foreground='blue'>🔄 Bezig met starten...</span>")
        
        threading.Thread(target=self._run, daemon=True).start()
    
    def _run(self):
        try:
            if not self.auto.start_chrome():
                GLib.idle_add(self._on_error, "Chrome starten mislukt")
                return
            
            GLib.idle_add(self._update_status, "🔑 Wacht op inloggen...")
            
            if not self.auto.wait_for_manual_login():
                GLib.idle_add(self._on_error, "Inloggen geannuleerd")
                return
            
            if not self.auto.load_products():
                GLib.idle_add(self._on_error, "Geen producten gevonden")
                return
            
            GLib.idle_add(self._update_status, "🔄 Bezig met verwerken...")
            self.auto.process_products()
            GLib.idle_add(self._on_finished)
            
        except Exception as e:
            GLib.idle_add(self._on_error, str(e))
    
    def _logged_in(self, widget):
        self.auto.user_logged_in = True
        self.login_btn.set_sensitive(False)
        self.logger.info("✅ Ingelogd bevestigd!")
    
    def _next(self, widget):
        self.next_btn.set_sensitive(False)
        self.skip_btn.set_sensitive(False)
        self.logger.info("⏭️ Door naar volgende...")
        self.auto.go_to_next()
    
    def _skip(self, widget):
        self.next_btn.set_sensitive(False)
        self.skip_btn.set_sensitive(False)
        self.logger.info("⏩ Overslaan...")
        threading.Thread(target=self.auto.skip_current, daemon=True).start()
    
    def _on_wait_for_user(self):
        GLib.idle_add(self._enable_next)
    
    def _stop(self, widget):
        self.running = False
        self.auto.running = False
        self.auto.stop()
        self.start_btn.set_sensitive(True)
        self.login_btn.set_sensitive(False)
        self.stop_btn.set_sensitive(False)
        self.next_btn.set_sensitive(False)
        self.skip_btn.set_sensitive(False)
        self.status_label.set_markup("<span foreground='red'>⏹️ Gestopt</span>")
        self.logger.info("⏹️ Gestopt door gebruiker")
    
    def _enable_next(self):
        self.next_btn.set_sensitive(True)
        self.skip_btn.set_sensitive(True)
    
    def _update_status(self, msg):
        self.status_label.set_markup(f"<span foreground='blue'>{msg}</span>")
    
    def _on_error(self, msg):
        self.logger.error(f"❌ {msg}")
        self.status_label.set_markup(f"<span foreground='red'>❌ Fout: {msg}</span>")
        self.start_btn.set_sensitive(True)
        self.login_btn.set_sensitive(False)
        self.stop_btn.set_sensitive(False)
        self.next_btn.set_sensitive(False)
        self.skip_btn.set_sensitive(False)
        self.running = False
    
    def _on_finished(self):
        self.logger.success("🎉 Alle producten verwerkt!")
        self.status_label.set_markup("<span foreground='green'>✅ Klaar!</span>")
        self.start_btn.set_sensitive(True)
        self.login_btn.set_sensitive(False)
        self.stop_btn.set_sensitive(False)
        self.next_btn.set_sensitive(False)
        self.skip_btn.set_sensitive(False)
        self.running = False
    
    def _clear_log(self, widget):
        buffer = self.log_text_view.get_buffer()
        buffer.set_text("")
        self.logger.info("🗑️ Log gewist")
    
    def _on_close(self, widget):
        if self.running:
            dialog = Gtk.MessageDialog(
                parent=self.window,
                flags=Gtk.DialogFlags.MODAL,
                message_type=Gtk.MessageType.QUESTION,
                buttons=Gtk.ButtonsType.YES_NO,
                text="Automatisering draait nog. Echt afsluiten?"
            )
            response = dialog.run()
            dialog.destroy()
            if response == Gtk.ResponseType.NO:
                return
        self.auto.close()
        Gtk.main_quit()
    
    def run(self):
        self.window.show_all()
        Gtk.main()

# ============================================
# MAIN
# ============================================

if __name__ == "__main__":
    app = App()
    app.run()
EOF

# Maak het script uitvoerbaar
chmod +x MarktplaatsAutomater/marktplaats_automater_gtk.py
echo -e "${GREEN}✅ marktplaats_automater_gtk.py aangemaakt${NC}"
echo ""

# ================================================
# STAP 8: Startscript aanmaken
# ================================================
echo -e "${YELLOW}🚀 Stap 8: Startscript aanmaken...${NC}"

cat > MarktplaatsAutomater/start.sh << 'EOF'
#!/bin/bash
# Start Marktplaats Automatisering met virtuele omgeving

# Ga naar de map waar het script staat
cd "$(dirname "$0")"

# Activeer virtuele omgeving
source venv/bin/activate

# Zet PYTHONPATH zodat de systeem GTK bindings gevonden worden
export PYTHONPATH="/usr/lib/python3/dist-packages:$PYTHONPATH"

# Start het GTK script
python3 marktplaats_automater_gtk.py

# Deactiveer virtuele omgeving bij afsluiten
deactivate
EOF

chmod +x MarktplaatsAutomater/start.sh
echo -e "${GREEN}✅ start.sh aangemaakt${NC}"
echo ""

# ================================================
# STAP 9: Applicatie snelkoppeling (.desktop)
# ================================================
echo -e "${YELLOW}🖥️  Stap 9: Applicatie snelkoppeling aanmaken...${NC}"

APP_DIR="$(pwd)/MarktplaatsAutomater"
ICON_PATH="${APP_DIR}/logo.png"
EXEC_PATH="${APP_DIR}/start.sh"

cat > MarktplaatsAutomater.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Marktplaats Automatisering
Comment=Automatiseer Marktplaats advertenties
Exec=${EXEC_PATH}
Icon=${ICON_PATH}
Terminal=false
StartupNotify=true
StartupWMClass=marktplaats_automater_gtk
Categories=Utility;Office;
EOF

mkdir -p ~/.local/share/applications
cp MarktplaatsAutomater.desktop ~/.local/share/applications/
chmod +x ~/.local/share/applications/MarktplaatsAutomater.desktop

if command -v update-desktop-database &> /dev/null; then
    update-desktop-database ~/.local/share/applications 2>/dev/null || true
fi

echo -e "${GREEN}✅ Snelkoppeling aangemaakt: MarktplaatsAutomater.desktop${NC}"
echo -e "${BLUE}   📌 GTK versie met correcte WM_CLASS voor Pin to Dash${NC}"
echo ""

# ================================================
# STAP 10: Controleer credentials.json
# ================================================
echo -e "${YELLOW}🔑 Stap 10: Controleer credentials.json...${NC}"

if [ -f "credentials.json" ]; then
    cp credentials.json MarktplaatsAutomater/
    echo -e "${GREEN}✅ credentials.json gekopieerd${NC}"
else
    echo -e "${YELLOW}⚠️  credentials.json niet gevonden!${NC}"
    echo -e "${BLUE}   📌 Plaats credentials.json in: ${PWD}/MarktplaatsAutomater/${NC}"
    echo -e "${BLUE}   📌 Download van: https://console.cloud.google.com/apis/credentials${NC}"
fi
echo ""

# ================================================
# STAP 11: Eerste configuratie aanmaken
# ================================================
echo -e "${YELLOW}⚙️  Stap 11: Configuratie aanmaken...${NC}"

if [ -f "MarktplaatsAutomater/config.json" ]; then
    echo -e "${BLUE}📌 config.json bestaat al, wordt niet overschreven (instellingen blijven behouden)${NC}"
else
    cat > MarktplaatsAutomater/config.json << 'EOF'
{
    "chrome": {
        "user_data_dir": "~/.config/google-chrome",
        "profile": "Default"
    },
    "google_sheets": {
        "sheet_url": "",
        "credentials_file": "credentials.json"
    },
    "paths": {
        "base_image_path": "~/Afbeeldingen"
    },
    "preferences": {
        "max_title_length": 60,
        "wait_between_products": 3
    }
}
EOF
    echo -e "${GREEN}✅ config.json aangemaakt${NC}"
fi
echo ""

# ================================================
# STAP 12: Finale boodschap
# ================================================
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                 INSTALLATIE VOLTOOID!                     ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📌 De applicatie is geïnstalleerd in:${NC}"
echo -e "   ${GREEN}${PWD}/MarktplaatsAutomater/${NC}"
echo ""
echo -e "${BLUE}📌 Start de applicatie op 2 manieren:${NC}"
echo ""
echo -e "${YELLOW}   1. Via het startscript:${NC}"
echo -e "      ${GREEN}cd MarktplaatsAutomater && ./start.sh${NC}"
echo ""
echo -e "${YELLOW}   2. Via de snelkoppeling:${NC}"
echo -e "      ${GREEN}Zoek 'Marktplaats Automatisering' in het applicatiemenu${NC}"
echo ""
echo -e "${BLUE}📌 Na het starten:${NC}"
echo -e "   1. ${YELLOW}Vul de instellingen in${NC} op het tabblad 'Instellingen'"
echo -e "   2. ${YELLOW}Klik op 'Opslaan'${NC}"
echo -e "   3. ${YELLOW}Ga naar 'Dashboard' en klik op 'Start'${NC}"
echo -e "   4. ${YELLOW}Log handmatig in${NC} op Marktplaats in de browser"
echo -e "   5. ${YELLOW}Klik op 'Ingelogd'${NC} in de GUI"
echo ""
echo -e "${GREEN}✅ Alles is klaar! Veel succes!${NC}"
echo -e "${BLUE}📌 GTK versie heeft automatisch de juiste WM_CLASS${NC}"
echo -e "${BLUE}   Pin to Dash werkt nu zonder extra configuratie!${NC}"
# ================================================
# WM_CLASS FORCEREN IN PYTHON CODE
# ================================================
echo -e "${YELLOW}🔧 WM_CLASS forceren in Python code...${NC}"
cd MarktplaatsAutomater

# Voeg de WM_CLASS toe aan de Python code
python3 << 'PYEOF'
with open('marktplaats_automater_gtk.py', 'r') as f:
    content = f.read()

if 'set_wmclass' not in content:
    # Voeg set_wmclass toe na de window creatie
    content = content.replace(
        'self.window = Gtk.Window()',
        'self.window = Gtk.Window()\n        self.window.set_wmclass("MarktplaatsAutomater", "MarktplaatsAutomater")'
    )
    
    # Voeg ook GLib.set_prgname toe
    if 'GLib.set_prgname' not in content:
        content = content.replace(
            'import gi',
            'import gi\nfrom gi.repository import GLib'
        )
        content = content.replace(
            'class App:',
            'class App:\n        GLib.set_prgname("MarktplaatsAutomater")'
        )

with open('marktplaats_automater_gtk.py', 'w') as f:
    f.write(content)
print("✅ WM_CLASS geforceerd naar: MarktplaatsAutomater")
PYEOF

cd ..
echo -e "${GREEN}✅ WM_CLASS fix toegepast${NC}"
echo ""
echo ""

# ================================================
# WM_CLASS FIXES VOOR PIN TO DASH
# ================================================
echo -e "${YELLOW}🔧 Stap 13: WM_CLASS forceren in Python code...${NC}"

cd MarktplaatsAutomater

# Fix 1: Font error
sed -i 's/set_font/modify_font/g' marktplaats_automater_gtk.py 2>/dev/null || true

# Fix 2: Voeg WM_CLASS toe aan Python code
python3 << 'PYEOF'
with open('marktplaats_automater_gtk.py', 'r') as f:
    content = f.read()

# Voeg set_wmclass toe
if 'set_wmclass' not in content:
    content = content.replace(
        'self.window = Gtk.Window()',
        'self.window = Gtk.Window()\n        self.window.set_wmclass("MarktplaatsAutomater", "MarktplaatsAutomater")'
    )

# Voeg GLib.set_prgname toe
if 'GLib.set_prgname' not in content:
    if 'from gi.repository import GLib' not in content:
        content = content.replace(
            'import gi',
            'import gi\nfrom gi.repository import GLib'
        )
    content = content.replace(
        'class App:',
        'class App:\n        GLib.set_prgname("MarktplaatsAutomater")'
    )

with open('marktplaats_automater_gtk.py', 'w') as f:
    f.write(content)
print("✅ WM_CLASS fix toegepast")
PYEOF

# Fix 3: Voeg X11 exports toe aan start_wayland.sh
if [ -f "start_wayland.sh" ]; then
    if ! grep -q "GDK_BACKEND=x11" start_wayland.sh; then
        sed -i '1a export GDK_BACKEND=x11' start_wayland.sh
    fi
    if ! grep -q "XDG_SESSION_TYPE=x11" start_wayland.sh; then
        sed -i '2a export XDG_SESSION_TYPE=x11' start_wayland.sh
    fi
fi

cd ..
echo -e "${GREEN}✅ Pin to Dash fixes toegepast${NC}"
echo ""

# Fix 4: Update de .desktop file met de juiste StartupWMClass
echo -e "${YELLOW}🔧 Stap 14: .desktop file updaten...${NC}"
cat > MarktplaatsAutomater.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Marktplaats Automatisering
Comment=Automatiseer Marktplaats advertenties
Exec=${PWD}/MarktplaatsAutomater/start_wayland.sh
Icon=${PWD}/MarktplaatsAutomater/logo.png
Terminal=false
StartupNotify=true
StartupWMClass=MarktplaatsAutomater
Categories=Utility;Office;
