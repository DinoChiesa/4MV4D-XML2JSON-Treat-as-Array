# XML2JSON - TreatAsArray option

This is an example proxy that illustrates how to use Apigee Edge to transform XML to
Json, while treating some elements within the XML as arrays, always.

By default, when transforming XML to JSON, Apigee Edge infers an array type when
multiple elements with the same element name are children of the same parent. This
works, most of the time. But in some cases, you would like the XML element to always be
treated as an array. For example, consider the case where the XML sometimes contains 1
child element, and sometimes 2 or more.  In the latter cases, it would be transformed to
an array, but in the special former case, it would not. This can be problematic for apps
that need to parse the resulting JSON.

## Example

Consider this source XML:

```xml
<root>
  <Item>
    <name>pod1</name>
    <region>us-east-1</region>
  </Item>
  <Item>
    <name>pod2</name>
    <region>us-west-2</region>
  </Item>
</root>
```

Apigee Edge, when transforming that XML to JSON, will always infer that the Item element
implies an array.  The resulting JSON will be like so:

```json

  "root": {
    "Item": [
      {
        "name": "pod1",
        "region": "us-east-1"
      },
      {
        "name": "pod2",
        "region": "us-west-2"
      }
    ]
  }
}
```

Now, suppose a very similar input XML document, but with just one child element. It looks like this:

```xml
<root>
  <Item>
    <name>pod1</name>
    <region>us-east-1</region>
  </Item>
</root>
```

The resulting JSON from that, will not include an array:

```json
{
  "root": {
    "Item": {
      "name": "pod1",
      "region": "us-east-1"
    }
  }
}
```

The difference appears to be small, but it results in a different programming model for
the receiving application. Therefore when transforming, it's helpful to be able to
"force" the creation of an array for some elements. So that with the latter input, we
can deliver this:

```json
{
  "root": {
    "Item": [
      {
        "name": "pod1",
        "region": "us-east-1"
      }
    ]
  }
}
```




## Pre-requisites for the Demo

To install and use this example yourself, on your own Apigee Edge organization, you
should clone this repo, and have a bash shell.  You should also (obviously?) have
orgadmin rights to a cloud-based Edge organization.  This feature is first available in
the OPDK, in version 16.09.

## Provisioning the demo

The easy way to provision this proxy is to use the
[provision-4mv4d-TreatAsArray-demo.sh](provision-4mv4d-TreatAsArray-demo.sh) script to
import the api proxy, and deploy it to the "test" environment in your organization.  You
may also want to manually zip the apiproxy directory and import it via the Apigee Edge
GUI.  That's probably going to be more difficult, but it's up to you.


## Running the demonstration

### The Transform without TreatAsArray

This shows the default behavior.  Apigee Edge does not always create the array.

Use the single-element input:
```
curl -i -T example-input-1-element.xml \
  -X POST \
  -H content-type:application/xml \
  https://ORGNAME-test.apigee.net/4mv4d-TreatAsArray-demo/xform1
```

Use the input with 2 elements
```
curl -i -T example-input-2-elements.xml \
  -X POST \
  -H content-type:application/xml \
  https://ORGNAME-test.apigee.net/4mv4d-TreatAsArray-demo/xform1
```

Compare the outputs of the above. You will see an array in the JSON for the latter, no
array for the former.  In these requests, Apigee Edge is invoking an XML2JSON policy that is configured like so:

```xml
<XMLToJSON name="XMLToJSON-1">
    <Options>
        <RecognizeNull>true</RecognizeNull>
        <TextNodeName>#text</TextNodeName>
        <AttributePrefix>@</AttributePrefix>
    </Options>
    <OutputVariable>response</OutputVariable>
    <Source>request</Source>
</XMLToJSON>
```

### The Transform *with* TreatAsArray

Now, invoke a different endpoint - replace xform1 with xform2. This cases 

Use the single-element input:
```
curl -i -T example-input-1-element.xml \
  -X POST \
  -H content-type:application/xml \
  https://ORGNAME-test.apigee.net/4mv4d-TreatAsArray-demo/xform2
```

Use the input with 2 elements
```
curl -i -T example-input-2-elements.xml \
  -X POST \
  -H content-type:application/xml \
  https://ORGNAME-test.apigee.net/4mv4d-TreatAsArray-demo/xform2
```

You will now see an array created in both cases.  In this case, Apigee Edge is invoking an XML2JSON policy that is configured with the TreatAsArray option, like so:

```xml
<XMLToJSON name="XMLToJSON-2-unwrap-false">
    <Options>
        <RecognizeNull>true</RecognizeNull>
        <TextNodeName>#text</TextNodeName>
        <AttributePrefix>@</AttributePrefix>
        <TreatAsArray>
            <Path unwrap="false">root/Item</Path>
        </TreatAsArray>
    </Options>
    <OutputVariable>response</OutputVariable>
    <Source>request</Source>
</XMLToJSON>
```

### The Transform *with* TreatAsArray, and unwrap

You'll notice that the resulting json from the above has a named array, like this:

```json
{
  "root": {
    "Item": [
      {
        "name": "pod1",
        "region": "us-east-1"
      }
    ]
  }
}
```

In some cases people may wish to eliminate the Item property from the generated JSON.  You can do this with the unwrap attribute on the TreatAsArray option.  The configuration is like this:

```xml
<XMLToJSON name="XMLToJSON-2-unwrap-true">
    <Options>
        <RecognizeNull>true</RecognizeNull>
        <TextNodeName>#text</TextNodeName>
        <AttributePrefix>@</AttributePrefix>
        <TreatAsArray>
            <Path unwrap="true">root/Item</Path>
        </TreatAsArray>
    </Options>
    <OutputVariable>response</OutputVariable>
    <Source>request</Source>
</XMLToJSON>
```

Notice: `unwrap="true"`.

To invoke this policy, use this command:

```
curl -i -T example-input-2-elements.xml \
  -X POST \
  -H content-type:application/xml \
  https://ORGNAME-test.apigee.net/4mv4d-TreatAsArray-demo/xform2-unwrap
```

You will notice the output like so :

```json
{
  "root": [
    {
      "name": "pod1",
      "region": "us-east-1"
    }
  ]
}
```

## Running the demonstration automatically.

You can also use the bash script to run all the example demonstrations. 

```
./run-4mv4d-TreatAsArray-demo.sh

```
