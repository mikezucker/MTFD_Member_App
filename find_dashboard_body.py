from pathlib import Path

text = Path("Features/Dashboard/Views/DashboardView.swift").read_text()

start = text.find("var body: some View {")
print("body start index:", start)

snippet = text[start:start+3000]
print(snippet)
