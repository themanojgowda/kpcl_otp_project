from flask import Flask, render_template

app = Flask(__name__)
app.config['TEMPLATES_AUTO_RELOAD'] = True

print("🔍 Testing template rendering...")

with app.app_context():
    html = render_template("index.html")
    print("✅ Template renders successfully")
