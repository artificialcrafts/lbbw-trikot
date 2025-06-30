# worker.py

import os
import subprocess
import time
import json
import boto3
import sys
import shutil
from pathlib import Path
from comfyui import ComfyUI

# --- Configuration ---
# These are now read from environment variables for flexibility
QUEUE_URL = "https://sqs.eu-central-1.amazonaws.com/320819923469/lbbw-trikot-queue"
AWS_REGION = os.environ.get("AWS_REGION", "eu-central-1") # Default to Frankfurt, change if needed

# Define temporary directories inside the container
OUTPUT_DIR = "/tmp/outputs"
INPUT_DIR = "/tmp/inputs"

def s3_upload(local_path, s3_url):
    """Uploads a file to S3 using the AWS CLI."""
    try:
        print(f"Uploading {local_path} to {s3_url}...")
        # Use --only-show-errors to keep the log clean on success
        subprocess.run(["aws", "s3", "cp", str(local_path), s3_url, "--only-show-errors"], check=True)
        print("Upload successful.")
    except subprocess.CalledProcessError as e:
        print(f"ERROR: S3 upload failed: {e}")
        raise # Re-raise the exception to signal that the job failed

def process_message(message, comfy_client):
    """Processes a single job message from the SQS queue."""
    print(f"--- New Job Received (MessageID: {message['MessageId']}) ---")
    
    try:
        job_data = json.loads(message['Body'])
        
        # Extract data from the job message
        workflow_data = job_data['workflow']
        s3_url = job_data['s3_url']
        
        # --- Prepare Inputs ---
        # The worker needs to clean the directories for each new job
        comfy_client.cleanup([OUTPUT_DIR, INPUT_DIR, "ComfyUI/temp"])

        # This example assumes inputs are defined in the workflow.
        # If you were downloading them from S3, that logic would go here.
        # For now, we'll assume the workflow points to public URLs or uses pre-baked inputs.
        
        # --- Run the workflow ---
        wf = comfy_client.load_workflow(workflow_data)
        comfy_client.connect()
        comfy_client.run_workflow(wf)
        
        output_files = comfy_client.get_files([OUTPUT_DIR, "ComfyUI/temp"])
        if not output_files:
            raise RuntimeError("Workflow did not generate any output files.")
        
        generated_file = output_files[0]
        
        s3_upload(generated_file, s3_url)

    except Exception as e:
        print(f"ERROR processing job: {e}")
        # Return False to indicate failure, so the message is not deleted from the queue
        return False

    return True # Indicate success

def main():
    if not QUEUE_URL:
        print("FATAL: SQS_QUEUE_URL environment variable not set. Exiting.")
        sys.exit(1)

    # --- 1. Start ComfyUI Server (once) ---
    comfyUI = ComfyUI("127.0.0.1:8188")
    server_process = comfyUI.start_server(OUTPUT_DIR, INPUT_DIR)
    
    # Initialize the SQS client
    sqs = boto3.client('sqs', region_name=AWS_REGION)
    
    print(f"Worker started successfully. Polling SQS queue: {QUEUE_URL}")
    
    # --- 2. The Main Worker Loop ---
    while True:
        try:
            response = sqs.receive_message(
                QueueUrl=QUEUE_URL,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=20 # Use long polling
            )

            if "Messages" in response:
                message = response["Messages"][0]
                receipt_handle = message['ReceiptHandle']
                
                success = process_message(message, comfyUI)
                
                if success:
                    sqs.delete_message(
                        QueueUrl=QUEUE_URL,
                        ReceiptHandle=receipt_handle
                    )
                    print("Job complete. Message deleted. Polling for next job...")
            else:
                # This is normal, it just means the queue was empty
                print(".", end="", flush=True)

        except KeyboardInterrupt:
            print("\nShutdown signal received. Exiting worker loop.")
            break
        except Exception as e:
            print(f"\nAn unexpected error occurred in the main loop: {e}")
            print("Sleeping for 10 seconds before retrying...")
            time.sleep(10)
    
    # --- 3. Shutdown ---
    print("Shutting down ComfyUI server...")
    server_process.terminate()
    server_process.wait()
    print("Worker stopped.")


if __name__ == "__main__":
    main()