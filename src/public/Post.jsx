import dtoken from 'ic:canisters/registry';
import * as React from 'react';
import Drawer from 'antd/es/drawer';
import Form from 'antd/es/form';
import Row from 'antd/es/row';
import Col from 'antd/es/col';
import Button from 'antd/es/button';
import Input from 'antd/es/input';
import InputNumber from 'antd/es/input-number';
import 'antd/lib/drawer/style';
import 'antd/lib/form/style';
import 'antd/lib/select/style';
import 'antd/lib/row/style';
import 'antd/lib/col/style';
import 'antd/lib/table/style';
import 'antd/lib/tag/style';
import 'antd/lib/button/style';
import 'antd/lib/input/style';
import 'antd/lib/input-number/style';

export default class Post extends React.Component {
    formRef = React.createRef();

    constructor(props) {
        super(props);
        this.state = {
            cycles: 3,
            post_visible: false,
        };
    }

    componentWillReceiveProps(nextProps) {
        this.setState({post_visible: nextProps.post_visible});
    }

    onClose = () => {
        this.setState({
            post_visible: false,
        });
    }

    handleOk = () => {
        const token = this.formRef.current.getFieldValue();
        // if ( this.state.cycles > 0) {
        dtoken.createToken(
            token.name, token.symbol, token.decimals, token.totalSupply
        ).then(function(result) {
            alert("Success: " + result);
            window.location.reload();
        }).catch(function (reason) {
            alert("Failed: " + reason);
        });
        this.setState({
            post_visible: false,
            // cycles: this.state.cycles - 1
        });
        // } else {
        //   alert("Your balance is not enough to post a job. _(:з」∠)_");
        // }
        
    };
    
    render() {

        return (
            <>
            <Drawer
              title="Create Your Token"
              width={720}
              onClose={this.onClose}
              visible={this.state.post_visible}
              bodyStyle={{ paddingBottom: 80 }}
              footer={
                <div
                style={{
                    textAlign: 'right',
                }}
                >
                    <Button onClick={this.onClose} style={{ marginRight: 8 }}>
                        Cancel
                    </Button>
                    <Button form="myForm" key="submit" type="primary" onClick={this.handleOk}>
                        Submit
                    </Button>
                </div>
            }
            >
            <Form layout="vertical" hideRequiredMark ref={this.formRef} id="myForm" >
                <Row gutter={16}>
                  <Col span={12}>
                    <Form.Item
                      name="name"
                      label="Name"
                      rules={[{ required: true, message: 'Please enter token name' }]}
                    >
                      <Input placeholder="Please enter token name" />
                    </Form.Item>
                  </Col>
                  <Col span={12}>
                    <Form.Item
                      name="symbol"
                      label="Symbol"
                      rules={[{ required: true, message: 'Please enter token symbol' }]}
                    >
                      <Input
                        style={{ width: '100%' }}
                        placeholder="Please enter token symbol"
                      />
                    </Form.Item>
                  </Col>
                </Row>
                <Row gutter={16}>
                  <Col span={12}>
                    <Form.Item
                      name="decimals"
                      label="Decimals"
                      rules={[{ required: true, message: 'Please enter token decimals' }]}
                    >
                      <InputNumber
                        style={{ width: '100%' }}
                        placeholder="18"
                      />
                    </Form.Item>
                  </Col>
                </Row>
                <Row gutter={16}>
                  <Col span={12}>
                    <Form.Item
                      name="totalSupply"
                      label="TotalSupply"
                      rules={[{ required: true, }]}
                    >
                      <InputNumber
                        style={{ width: '100%' }}
                        placeholder="21000000"
                      />
                    </Form.Item>
                  </Col>
                </Row>
              </Form>
              </Drawer>
            </>
        );
    }
}

