
Sentinel 1 (SAR) data pre-processing
===============================

This project is a use case of [Sentinel
1](https://sentinel.esa.int/web/sentinel/missions/sentinel-1) data preparation
for further quantitative analysis on Earth observation.  The processing takes a
list of satellite images as an input and outputs them merged into an animated
GIF. The automated deployment of the application into clouds is performed using
the [Nuvla](https://nuv.la) service which is based on
[SlipStream](http://sixsq.com/products/slipstream) and operated by
[SixSq](http://sixsq.com).

The processing of the satellite images is distributed using the MapReduce model.
The input and output files are stored in an object store
located in the cloud.  This implementation aims to minimize the execution time.

The number of `mappers` deployed is dependent on the number of scenes to process.  This provides
the benefits of having a constant map phase, which is important to prepare for the next phase of
the project, which is to enable SLA-bound Earth Observation products creation.  For example,
`time-to-product-creation` could be an SLA that the service must enforce, independently of the
number of scenes to process, or the number of concurrent request received.

Using Nuvla, the system is portable accros clouds, which means users can choose any cloud to
perform the processing, as long as they have corresponding credentials in their Nuvla account.

Finally, this approach is `clean` in terms of resource consumption, in the sense that resources
are only required for the processing of scenes.  Once the processing is completed, the resources
are terminated, therefore stopping any associated cloud costs.  Only the data left in the object
store will continue to incur costs.  But since object store is the cheapest way to store data in
cloud services, this cost is reduced to a minimum.  Furthermore, if the output product is deleted
from the object store after delivery to the end-user, this costs would be eliminated all together.


## Prerequisites

In order to successfully execute the application, you should have:

 1. An account on [Nuvla](https://nuv.la).  Follow this
    [link](http://ssdocs.sixsq.com/en/latest/tutorials/ss/prerequisites.html#nuvla-account)
    where you'll find how to create the account.

 2. Cloud credentials added in your Nuvla user profile
    <div style="padding:14px"><img
    src="https://github.com/SimonNtz/SAR_app/blob/master/run/NuvlaProfile.png"
    width="75%"></div>

 3. Python `>=2.6 and <3` and python package manager `pip` installed. Usually
    can be installed with `sudo easy_install pip`.

 4. SlipStream Client installed: `pip install slipstream-client`.


## Instructions

 1. Clone this repository with

    ```
    $ git clone https://github.com/SimonNtz/SAR_app.git
    ```

 2. Add the list of products into the input file

    ```
    $ cd SAR_app/run/
    $ # edit product_list.cfg
    ```

 3. Set the environment variables

    ```
    $ export SLIPSTREAM_USERNAME=<nuv.la username>
    $ export SLIPSTREAM_PASSWORD=<nuv.la password>
    ```

    and run the SAR processor on [Nuvla](https://nuv.la) with

    ```
    $ ./SAR_run.sh <cloud>
    ```

    Where `<cloud>` is the connector instance name as defined in Nuvla
    and for which you have defined your cloud credentials (see section 2. of
    Prerequisites above).

 4. The command prints out the deployment URL which you can open in your
    browser to follow the progress of the deployment.  When the deployment is
    done, the link to the result of the computation becomes available as the
    run-time parameter `ss:url.service` in the deployment Global section.
    Also, the command follows the progress of the deployment, detects when
    the deployment has finished, recovers and prints the link to the result
    of the computation.

## Modularity

The *SAR_app's* scripts form the application's base however the map and reduce functions are located in an other *Github* repository, by default [SAR_proc](https://github.com/SimonNtz/SAR_proc/).
During the deployment it get cloned locally using an application's parameter containing its respective URL.  
The intent behind isolating the SAR processor is to make it customizable to the users with less effort.

While running the client script, a *Github* repository url respecting the [SAR_proc](https://github.com/SimonNtz/SAR_proc/) requirements can be pass as an input parameter.

```
$ ./SAR_run.sh <cloud> <https://github.com/YOUR_USERNAME/SAR_proc>
```


## Scope

European Space Agency [ESA](ESA) provides Earth Observation Data captured by their [Sentinel-1](http://www.esa.int/Our_Activities/Observing_the_Earth/Copernicus/Sentinel-1/Introducing_Sentinel-1) satellites fleet. Being constantly populated this dataset posses now a big potential to be exploited in a wide spectrum of applications.

## Implementation

The processing of the satellite images are done using the [SNAP toolbox](http://step.esa.int/main/toolboxes/snap/) and its Sentinel-1 module [S1tbx](https://sentinel.esa.int/web/sentinel/toolboxes/sentinel-1). This computation is distributed over multiple nodes within a cloud cluster. The global execution is divided in two steps following the MapReduce model.  Finally, the implementation aims to minimize the
execution time.

*NOTE: in-progress, not fully optimize yet.*

## SAR Processor stages

The full image processing is done by calling multiple functions of the S1tbx. Here are the ones that we used.

  1. Subsetting (crop image on ROI)
  2. Calibration (radiometric, outputting beta-nought)
  3. Speckle-Filter (Dopler effect correction)
  4. Terrain correction (Foreshortening and layover)
  5. Linear to DB pixels conversion
  1. Conversion in *PNG* format
