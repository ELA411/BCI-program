setenv('ROS_DOMAIN_ID', '30')
node = ros2node("/matlab_nodec");
pub = ros2publisher(node, '/cmd_vel', 'geometry_msgs/Twist');
msg = ros2message(pub);
msg.linear.x = 1; % Linear speed
msg.angular.Z = 0.1; % Angular velocity
send(pub, msg);
