# worker.py (Final Version with S3 Input and Output)

import os
import subprocess
import time
import json
import boto3
import sys
import shutil
import random
from pathlib import Path
from comfyui import ComfyUI

# --- Configuration ---
QUEUE_URL = os.environ.get("SQS_QUEUE_URL", "https://sqs.eu-central-1.amazonaws.com/320819923469/lbbw-trikot-queue")
AWS_REGION = os.environ.get("AWS_REGION", "eu-central-1")
OUTPUT_DIR = "/tmp/outputs"
INPUT_DIR = "/tmp/inputs"

def s3_operation(s3_path_from, local_path_to, direction='download'):
    """Handles both upload and download using AWS CLI."""
    try:
        if direction == 'download':
            print(f"Downloading {s3_path_from} to {local_path_to}...")
            command = ["aws", "s3", "cp", s3_path_from, local_path_to, "--only-show-errors"]
        else: # upload
            print(f"Uploading {local_path_to} to {s3_path_from}...")
            command = ["aws", "s3", "cp", local_path_to, s3_path_from, "--only-show-errors"]
        
        subprocess.run(command, check=True)
        print(f"{direction.capitalize()} successful.")
    except subprocess.CalledProcessError as e:
        print(f"ERROR: S3 {direction} failed: {e}")
        raise

def process_message(message, comfy_client):
    """Processes a single job message from the SQS queue."""
    print(f"--- New Job Received (MessageID: {message['MessageId']}) ---")
    
    try:
        job_data = json.loads(message['Body'])
        
        # --- Prepare Inputs ---
        comfy_client.cleanup([OUTPUT_DIR, INPUT_DIR, "ComfyUI/temp"])

        if 'inputs' in job_data:
            for local_filename, s3_uri in job_data['inputs'].items():
                destination_path = os.path.join(INPUT_DIR, local_filename)
                s3_operation(s3_uri, destination_path, direction='download')
        
        # --- Run Workflow ---
        workflow_data = job_data['workflow']
        wf = comfy_client.load_workflow(workflow_data)
        comfy_client.connect()
        comfy_client.run_workflow(wf)
        
        output_files = comfy_client.get_files([OUTPUT_DIR, "ComfyUI/temp"])
        if not output_files:
            raise RuntimeError("Workflow did not generate any output files.")
        
        generated_file = output_files[0]
        
        # --- Upload Result ---
        s3_url = job_data['s3_url']
        s3_operation(s3_url, str(generated_file), direction='upload')

    except Exception as e:
        print(f"ERROR processing job: {e}")
        return False # Indicate failure

    return True

def main():
    if not QUEUE_URL:
        # This check is still good as a safeguard, though it's less likely to fail now.
        print("FATAL: SQS_QUEUE_URL is not configured. Exiting.")
        sys.exit(1)

    # --- Start ComfyUI Server (once) ---
    comfyUI = ComfyUI("127.0.0.1:8188")
    server_process = comfyUI.start_server(OUTPUT_DIR, INPUT_DIR)
    
    sqs = boto3.client('sqs', region_name=AWS_REGION)
    
    print(f"Worker started. Polling SQS queue: {QUEUE_URL}")
    
    # --- Main Worker Loop ---
    while True:
        try:
            response = sqs.receive_message(
                QueueUrl=QUEUE_URL,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=20
            )

            if "Messages" in response:
                message = response["Messages"][0]
                receipt_handle = message['ReceiptHandle']
                
                if process_message(message, comfyUI):
                    sqs.delete_message(
                        QueueUrl=QUEUE_URL,
                        ReceiptHandle=receipt_handle
                    )
                    print("Job complete. Message deleted. Polling for next job...")
            else:
                print(".", end="", flush=True)

        except KeyboardInterrupt:
            print("\nShutdown signal received. Exiting worker loop.")
            break
        except Exception as e:
            print(f"\nAn unexpected error occurred in the main loop: {e}")
            time.sleep(10)
    
    # --- Shutdown ---
    print("Shutting down ComfyUI server...")
    server_process.terminate()
    server_process.wait()
    print("Worker stopped.")


if __name__ == "__main__":
    main()