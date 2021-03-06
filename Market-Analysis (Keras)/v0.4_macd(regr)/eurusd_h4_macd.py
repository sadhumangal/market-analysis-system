# -*- coding: utf-8 -*-
###############################################################################
#                                                                             #
#   Market Analysis System                                                    #
#   https://www.mql5.com/ru/users/terentjew23                                 #
#                                                                             #
#   M A R K E T   A N A L Y S I S   S C R I P T   W I T H   K E R A S         #
#                                                                             #
#   Aleksey Terentew                                                          #
#   terentew.aleksey@ya.ru                                                    #
#                                                                             #
###############################################################################

from __future__ import print_function
import matplotlib.pyplot as plt
import numpy as np
import math
from keras.backend import backend
from keras.models import Sequential, model_from_json
from keras.layers import Dense, GRU, Reshape, normalization
from sklearn.metrics import mean_squared_error

#=============================================================================#
batch_size =    64
nb_epoch =      100
epochs =        1

workfile = 'EURUSD.pro240'
prefix = 'eurusd_h4_macd'
path = 'C:/Program Files (x86)/STForex MetaTrader 4/MQL4/Files/ML-Assistant/'
#=============================================================================#
file_x = path + workfile + '_x.csv'
file_y = path + workfile + '_y.csv'
file_xx = path + workfile + '_xx.csv'
file_yy = path + workfile + '_yy.csv'

np.random.seed(7)

print( 'Backend =', backend() )
print( workfile )
#=============================================================================#
#       Load Data                                                             #
#=============================================================================#
print( 'Prepare Data...' )

data_x = np.genfromtxt(file_x, delimiter=';')
data_y = np.genfromtxt(file_y, delimiter=';')

# (batch_size, timesteps, units)
data_x = np.reshape( data_x, (data_x.shape[0], 1, 1) )

print( "data_x:", data_x.shape )
print( "data_y:", data_y.shape )

train_size = int( len(data_x) * 0.67 )
test_size = len(data_x) - train_size
train_x, test_x = data_x[0:train_size,:], data_x[train_size:len(data_x),:]
print( len(train_x), len(test_x) )
train_y, test_y = data_y[0:train_size,], data_y[train_size:len(data_y),]
print( len(train_y), len(test_y) )
#=============================================================================#
#       Prepare Model                                                         #
#=============================================================================#
print( '\nCreating or Load Model...' )

json_string = ''
try:
    f = open( prefix+'_mas.model', 'r' )
except IOError as e:
    print( 'Model created' )
else:
    json_string = f.read()
    f.close()
    print( 'Model loaded' )
    
if( len(json_string) > 0 ):
    model = model_from_json( json_string )
else:
    model = Sequential()
#    model.add( normalization.BatchNormalization( batch_input_shape=(None, 1, 15) ) )
    model.add( GRU( 4, input_shape=(1, 1) ) )
#    model.add( Reshape( (1,1) ) )
#    model.add( GRU( 4 ) )
    model.add( Dense( 1 ) )#, activation='tanh' ) )

model.compile( loss='mse', optimizer='adam', metrics=['mae', 'acc'] )

json_string = model.to_json()
with open( prefix+'_mas.model', 'w' ) as f:
    f.write(json_string)
#=============================================================================#
#       Training                                                              #
#=============================================================================#
print( '\nTraining...' )

try:
    model.load_weights( prefix+'_weights.hdf5', by_name=False )
except IOError as e:
    print( 'Weights file is empty. New train' )
else:
    print( 'Weights loaded' )
    
for i in range( epochs ):
    print( 'Epoch', i+1, '/', epochs )
    model.fit( train_x, train_y, batch_size=batch_size,
              nb_epoch=nb_epoch)
    
model.save_weights( prefix+'_weights.hdf5' )
#model.reset_states()
#=============================================================================#
#       Predicting                                                            #
#=============================================================================#
print( '\nPredicting...' )

data_xx = np.genfromtxt( file_xx, delimiter=';' )
data_xx = np.reshape( data_xx, (data_xx.shape[0], 1, 1) )

print( "data_xx:", data_xx.shape )

predicted_output = model.predict( data_xx, batch_size=batch_size )

np.savetxt( file_yy, predicted_output, fmt='%.6f', delimiter=';' )

print( "Predict saved:", file_yy )
#=============================================================================#
#       Plot                                                                  #
#=============================================================================#
#print( '\nResults' )
#plt.subplot(2, 1, 1)
#plt.plot(expected_output)
#plt.title('Expected')
#plt.subplot(2, 1, 2)
plt.plot( predicted_output )
plt.title('Predicted')
plt.show()


# make predictions
trainPredict = model.predict(train_x)
testPredict = model.predict(test_x)
# calculate root mean squared error
trainScore = math.sqrt(mean_squared_error(train_y, trainPredict))
print('Train Score: %.6f RMSE' % (trainScore))
testScore = math.sqrt(mean_squared_error(test_y, testPredict))
print('Test Score: %.6f RMSE' % (testScore))

# shift train predictions for plotting
trainPredictPlot = np.empty_like(data_y)
trainPredictPlot[:] = np.nan
trainPredictPlot[1:len(trainPredict)+1] = trainPredict[0]
# shift test predictions for plotting
testPredictPlot = np.empty_like(data_y)
testPredictPlot[:] = np.nan
testPredictPlot[len(trainPredict)+(1*2)+1:len(data_y)-1] = testPredict[0]
# plot baseline and predictions
plt.plot(data_y)
plt.plot(trainPredictPlot)
plt.plot(testPredictPlot)
plt.show()
