from playwright.sync_api import sync_playwright, Page, expect

def run_verification():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        try:
            # Go to the gesture control page
            page.goto("http://localhost:8000/gesture", timeout=10000)

            # Wait for the status to indicate the model is ready
            status_div = page.locator("#status")
            expect(status_div).to_have_text("Ready! Detecting hands...", timeout=30000)

            # Add a delay to allow time for a hand to be placed in front of the camera
            # This is for demonstration purposes to get a good screenshot
            page.wait_for_timeout(5000)

            # Take a screenshot
            page.screenshot(path="jules-scratch/verification/gesture_verification.png")

            print("Screenshot taken successfully.")

        except Exception as e:
            print(f"An error occurred during verification: {e}")
        finally:
            browser.close()

if __name__ == "__main__":
    run_verification()
