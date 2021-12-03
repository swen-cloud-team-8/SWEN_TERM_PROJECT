import boto3
import numpy as np
import cv2
import json
import pafy
import io
from scipy.spatial import distance as dist
# import time


from PIL import Image, ImageDraw, ExifTags, ImageColor


frame_skip = 10
cur_frame = 0
MIN_DISTANCE = 100

# Online Video
# url   = "https://www.youtube.com/watch?v=ORrrKXGx2SE"
# video = pafy.new(url)
# best  = video.getbest(preftype="mp4")
# capture = cv2.VideoCapture(best.url)


#upload bucket4



#Get video from S3
s3_client = boto3.client('s3')
# bucket = 'amplify-bucket'      
# key = 'pedestrians.mp4' 
# url = s3_client.generate_presigned_url('get_object', 
#                                        Params = {'Bucket': bucket, 'Key': key}, 
#                                        ExpiresIn = 600) #this url will be available for 600 seconds  
# capture = cv2.VideoCapture(url)
       



# #local video
capture = cv2.VideoCapture("pedestrians.mp4")

# Create a Rekognition client
client=boto3.client('rekognition')


while True:
	violate = set()
	success, frame = capture.read() # get next frame from video
	if not success:
		break
	# frame = cv2.resize(frame, (1080,720), interpolation = cv2.INTER_AREA)
	imgHeight,imgWidth, channels = frame.shape

	if cur_frame % frame_skip == 0: # only analyze every n frames
		print('Working on frame number : {}'.format(cur_frame)) 

		pil_img = Image.fromarray(frame) # convert opencv frame (with type()==numpy) into PIL Image
		stream = io.BytesIO()
		pil_img.save(stream, format='JPEG') # convert PIL Image to Bytes
		bin_img = stream.getvalue()

		response = client.detect_labels(Image={'Bytes': bin_img}) # call Rekognition
		persons = next(item for item in response['Labels'] if item["Name"] == "Person")

		if(len(persons["Instances"]) >= 2):


			centroids = np.array([(  (r["BoundingBox"]["Left"]+(r["BoundingBox"]["Width"])/2)*imgWidth, \
									(r["BoundingBox"]["Top"]+(r["BoundingBox"]["Height"])/2)*imgHeight   ) \
									for r in persons["Instances"] ])

			
			D = dist.cdist(centroids, centroids, metric="euclidean")
			# loop over the upper triangular of the distance matrix
			for i in range(0, D.shape[0]):
				for j in range(i + 1, D.shape[1]):
					# check to see if the distance between any two
					# centroid pairs is less than the configured number
					# of pixels
					if D[i, j] < MIN_DISTANCE:
						# update our violation set with the indexes of
						# the centroid pairs
						violate.add(i)
						violate.add(j)

		# loop over the results
		for j in range(len(persons["Instances"])):
			# extract the bounding box and centroid coordinates, then
			# initialize the color of the annotation
			# (startX, startY, endX, endY) = bbox
			
			dimensions = (persons["Instances"][j]["BoundingBox"])
			#Storing them in variables       
			boxWidth = dimensions['Width']
			boxHeight = dimensions['Height']
			boxLeft = dimensions['Left']
			boxTop = dimensions['Top']
			#Plotting points of rectangle
			start_point = (int(boxLeft*imgWidth), int(boxTop*imgHeight))
			end_point = (int((boxLeft + boxWidth)*imgWidth),int((boxTop + boxHeight)*imgHeight))
			#Drawing Bounding Box on the coordinates 

			# if the index pair exists within the violation set, then
			color = (0, 255, 0)
			# update the color
			if j in violate:
				color = (0, 0, 255)

			# draw (1) a bounding box around the person and (2) the
			# centroid coordinates of the person,
			cv2.rectangle(frame, start_point, end_point, color, 2)
				
		if len(violate) > 15:
			image_string = cv2.imencode('.jpg', frame)[1].tostring()
			s3_client.put_object(Bucket="sns-src-bucket", Key = str(cur_frame)+".jpeg", Body=image_string)

		frame = cv2.resize(frame, (420,360), interpolation = cv2.INTER_AREA)
		frame_string = cv2.imencode('.jpg', frame)[1].tostring()
		s3_client.put_object(Bucket="amplify-src-bucket", Key = "output.jpeg", Body=frame_string)
		# time.sleep(5) 
		# frame = cv2.resize(frame, (1080,720), interpolation = cv2.INTER_AREA)
		# cv2.imshow('labelled.jpg',frame)
		# if cv2.waitKey(1) & 0xFF == ord('q'):
			# break

		
	cur_frame += 1
# cv2.destroyAllWindows()
